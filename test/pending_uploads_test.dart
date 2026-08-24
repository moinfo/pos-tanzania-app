import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pos_tanzania_mobile/models/pending_upload.dart';
import 'package:pos_tanzania_mobile/services/database_service.dart';
import 'package:pos_tanzania_mobile/services/offline_actions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The three states a record can be in before it reaches the server, and the
/// one of them that loses data.
///
/// Waiting and Trying are bookkeeping: both go up on their own, and the only
/// thing a person can do about either is have a better connection. REJECTED is
/// different in kind -- the server looked at the record and refused it, so no
/// retry will ever move it, and if nobody is told, the work behind it is gone.
///
/// So what is defended here is: the three are distinguishable, a refusal
/// carries the server's own words, and a refusal that nobody has read survives
/// the app being killed. That last one matters because the obvious place to
/// keep "has anyone seen this?" is memory, and memory is exactly what a
/// force-quit throws away.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = DatabaseService.instance;
    await db.closeDatabase();
    await db.initDatabaseAt(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.closeDatabase();
  });

  Future<int> queueExpense({
    String requestId = 'key-1',
    double amount = 5000,
    String summary = 'Fuel',
  }) =>
      db.queueAction(
        actionType: OfflineAction.expense.type,
        endpoint: OfflineAction.expense.endpoint,
        label: OfflineAction.expense.label,
        requestId: requestId,
        payload: {'amount': amount, 'description': summary},
        summary: summary,
      );

  /// The sync queue row the uploader actually reads for a given action.
  Future<Map<String, dynamic>> queueRowFor(int actionId) async {
    final rows = await db.getPendingSyncItems(
      entityType: DatabaseService.pendingActionEntity,
    );
    return rows.firstWhere((r) => r['entity_id'] == actionId);
  }

  Future<PendingUpload> onlyUpload() async {
    final merged = PendingUpload.merge(
      sales: await db.getUnsyncedSales(),
      actions: await db.getUnsyncedActions(),
    );
    expect(merged, hasLength(1));
    return merged.single;
  }

  // =========================================================================
  group('the three states are told apart', () {
    test('a record nobody has tried to upload is WAITING', () async {
      await queueExpense();

      final item = await onlyUpload();
      expect(item.state, UploadState.waiting);
      expect(item.attempts, 0);
      expect(item.kind, 'Expense');
      expect(item.detail, 'Fuel');
    });

    test('attempts that never reached the server leave it WAITING', () async {
      final id = await queueExpense();
      final queueId = (await queueRowFor(id))['id'] as int;

      // What a week out of coverage looks like: many attempts, no answer.
      for (var i = 0; i < 20; i++) {
        await db.recordSyncQueueAttempt(queueId, 'No internet connection');
      }

      // Still waiting, and still zero attempts against it. This is the whole
      // point of recordSyncQueueAttempt not touching retry_count: a phone in a
      // dead spot must not end up looking like a phone with a problem.
      final item = await onlyUpload();
      expect(item.state, UploadState.waiting);
      expect(item.attempts, 0);
    });

    test('an answer the server may give differently later is TRYING',
        () async {
      final id = await queueExpense();
      final queueId = (await queueRowFor(id))['id'] as int;

      // What sync_service does for a 5xx or an expired token: countable,
      // because this one can run out of road.
      await db.updateSyncQueueStatus(
        queueId,
        DatabaseService.syncStatusPending,
        error: 'Server error (500)',
      );
      await db.updateSyncQueueStatus(
        queueId,
        DatabaseService.syncStatusPending,
        error: 'Server error (500)',
      );

      final item = await onlyUpload();
      expect(item.state, UploadState.trying);
      expect(item.attempts, 2);
      expect(item.reason, 'Server error (500)');
    });

    test('a refusal the server will repeat is REJECTED, in its own words',
        () async {
      final id = await queueExpense();
      final queueId = (await queueRowFor(id))['id'] as int;

      const refusal = 'Expense amount must be greater than zero';
      await db.updateSyncQueueStatus(
        queueId,
        DatabaseService.syncStatusFailed,
        error: refusal,
      );
      await db.updatePendingActionStatus(
        id,
        DatabaseService.syncStatusFailed,
        error: refusal,
      );

      final item = await onlyUpload();
      expect(item.state, UploadState.rejected);
      // The server's own words, not a paraphrase. Whoever has to fix this
      // needs to know WHAT was wrong, and only the server knows that.
      expect(item.reason, refusal);
      expect(item.isUnreadRejection, isTrue);
    });

    test('a rejected record is NOT picked up by the uploader again', () async {
      final id = await queueExpense();
      final queueId = (await queueRowFor(id))['id'] as int;

      await db.updateSyncQueueStatus(
        queueId,
        DatabaseService.syncStatusFailed,
        error: 'Refused',
      );
      await db.updatePendingActionStatus(
        id,
        DatabaseService.syncStatusFailed,
        error: 'Refused',
      );

      // getPendingSyncItems is the only thing the uploader reads. A rejected
      // record must not be in it -- otherwise "will never upload on its own"
      // would be a lie in the opposite direction: it would grind forever.
      final pending = await db.getPendingSyncItems(
        entityType: DatabaseService.pendingActionEntity,
      );
      expect(pending.where((r) => r['entity_id'] == id), isEmpty);
    });

    test('a sale runs through the same three states', () async {
      final saleId = await db.createLocalSale(
        {
          'employee_id': 1,
          'sale_time': DateTime.now().toIso8601String(),
          'total': 12000.0,
        },
        const [],
        const [],
        requestId: 'sale-key-1',
      );

      var item = await onlyUpload();
      expect(item.isSale, isTrue);
      expect(item.state, UploadState.waiting);
      expect(item.amount, 12000.0);

      final queueRow = (await db.getPendingSyncItems(entityType: 'sale'))
          .firstWhere((r) => r['entity_id'] == saleId);
      await db.updateSyncQueueStatus(
        queueRow['id'] as int,
        DatabaseService.syncStatusPending,
        error: 'Server error (503)',
      );
      item = await onlyUpload();
      expect(item.state, UploadState.trying);

      await db.updateSyncQueueStatus(
        queueRow['id'] as int,
        DatabaseService.syncStatusFailed,
        error: 'Item 44 is not stocked at this location',
      );
      await db.updateSaleSyncStatus(
        saleId,
        DatabaseService.syncStatusFailed,
        error: 'Item 44 is not stocked at this location',
      );
      item = await onlyUpload();
      expect(item.state, UploadState.rejected);
      expect(item.reason, 'Item 44 is not stocked at this location');
      expect(item.requestId, 'sale-key-1');
    });

    test('a tally counts the three separately', () async {
      await queueExpense(requestId: 'k1', summary: 'Fuel');
      final trying = await queueExpense(requestId: 'k2', summary: 'Airtime');
      final rejected = await queueExpense(requestId: 'k3', summary: 'Rent');

      await db.updateSyncQueueStatus(
        (await queueRowFor(trying))['id'] as int,
        DatabaseService.syncStatusPending,
        error: 'Server error (500)',
      );
      await db.updateSyncQueueStatus(
        (await queueRowFor(rejected))['id'] as int,
        DatabaseService.syncStatusFailed,
        error: 'Refused',
      );
      await db.updatePendingActionStatus(
        rejected,
        DatabaseService.syncStatusFailed,
        error: 'Refused',
      );

      final tally = PendingUploadTally.of(PendingUpload.merge(
        sales: await db.getUnsyncedSales(),
        actions: await db.getUnsyncedActions(),
      ));

      expect(tally.waiting, 1);
      expect(tally.trying, 1);
      expect(tally.rejected, 1);
      expect(tally.unreadRejections, 1);
      expect(tally.total, 3);
    });
  });

  // =========================================================================
  group('what a person can do about a refusal', () {
    late int actionId;

    setUp(() async {
      actionId = await queueExpense();
      await db.updateSyncQueueStatus(
        (await queueRowFor(actionId))['id'] as int,
        DatabaseService.syncStatusFailed,
        error: 'Duplicate document number',
      );
      await db.updatePendingActionStatus(
        actionId,
        DatabaseService.syncStatusFailed,
        error: 'Duplicate document number',
      );
    });

    test('reading it clears the warning without clearing the record',
        () async {
      expect(await db.countUnreadRejections(), 1);

      await db.acknowledgeRejection(
        entityType: DatabaseService.pendingActionEntity,
        id: actionId,
      );

      // The alarm stops; the problem does not. The record is still refused,
      // still listed, still not on the server.
      expect(await db.countUnreadRejections(), 0);
      final item = await onlyUpload();
      expect(item.state, UploadState.rejected);
      expect(item.acknowledged, isTrue);
    });

    test('retrying by hand puts it back in the queue, keeping its key',
        () async {
      final before = await db.getPendingAction(actionId);
      final key = before!['request_id'] as String;

      expect(
        await db.reopenRejected(
          entityType: DatabaseService.pendingActionEntity,
          id: actionId,
        ),
        isTrue,
      );

      final item = await onlyUpload();
      expect(item.state, UploadState.waiting);
      expect(item.attempts, 0);

      // The uploader can see it again...
      final queued = await db.getPendingSyncItems(
        entityType: DatabaseService.pendingActionEntity,
      );
      expect(queued.where((r) => r['entity_id'] == actionId), hasLength(1));

      // ...and it will go up under the SAME key it was first written under,
      // which is what makes a hand retry safe: if the earlier attempt did
      // reach the server, the server replays that answer rather than writing
      // a second record.
      final after = await db.getPendingAction(actionId);
      expect(after!['request_id'], key);
      expect(after['sync_error'], isNull);
    });

    test('giving up is deliberate, and never a delete', () async {
      expect(
        await db.discardRejected(
          entityType: DatabaseService.pendingActionEntity,
          id: actionId,
        ),
        isTrue,
      );

      // Gone from the queue, gone from the counts, gone from the warning.
      expect(
        PendingUpload.merge(
          sales: await db.getUnsyncedSales(),
          actions: await db.getUnsyncedActions(),
        ),
        isEmpty,
      );
      expect(await db.countUnreadRejections(), 0);
      expect((await db.getUnsyncedActionCounts())['failed'], 0);
      expect(
        await db.getPendingSyncItems(
          entityType: DatabaseService.pendingActionEntity,
        ),
        isEmpty,
      );

      // But the record itself is still there, with its payload and the
      // server's words, so the question can still be answered next week.
      final row = await db.getPendingAction(actionId);
      expect(row, isNotNull);
      expect(row!['sync_status'], DatabaseService.syncStatusDiscarded);
      expect(row['payload'], contains('Fuel'));
      expect(row['sync_error'], 'Duplicate document number');
    });

    test('nothing acts on a record that is not refused', () async {
      final waiting = await queueExpense(requestId: 'k9', summary: 'Water');

      expect(
        await db.reopenRejected(
          entityType: DatabaseService.pendingActionEntity,
          id: waiting,
        ),
        isFalse,
      );
      expect(
        await db.discardRejected(
          entityType: DatabaseService.pendingActionEntity,
          id: waiting,
        ),
        isFalse,
      );
    });
  });

  // =========================================================================
  group('a refusal outlives the app', () {
    late Directory dir;
    late String path;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('pending_uploads_test');
      path = p.join(dir.path, 'restart.db');
      // The in-memory database from the outer setUp proves nothing about
      // surviving a force-quit, so this group works on a real file.
      await db.closeDatabase();
      await db.initDatabaseAt(path);
    });

    tearDown(() async {
      await db.closeDatabase();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('an unread rejection is still unread after a restart', () async {
      final id = await queueExpense(requestId: 'restart-key');
      await db.updateSyncQueueStatus(
        (await queueRowFor(id))['id'] as int,
        DatabaseService.syncStatusFailed,
        error: 'Stock location 7 is closed',
      );
      await db.updatePendingActionStatus(
        id,
        DatabaseService.syncStatusFailed,
        error: 'Stock location 7 is closed',
      );
      expect(await db.countUnreadRejections(), 1);

      // Force-quit and relaunch.
      await db.closeDatabase();
      await db.initDatabaseAt(path);

      // The warning comes back, because "has anyone seen this?" was never
      // held in memory. Killing the app is not an acknowledgement.
      expect(await db.countUnreadRejections(), 1);
      final item = await onlyUpload();
      expect(item.state, UploadState.rejected);
      expect(item.reason, 'Stock location 7 is closed');
      expect(item.isUnreadRejection, isTrue);
    });

    test('once it has been read, a restart does not raise it again', () async {
      final id = await queueExpense(requestId: 'restart-key-2');
      await db.updateSyncQueueStatus(
        (await queueRowFor(id))['id'] as int,
        DatabaseService.syncStatusFailed,
        error: 'Refused',
      );
      await db.updatePendingActionStatus(
        id,
        DatabaseService.syncStatusFailed,
        error: 'Refused',
      );
      await db.acknowledgeRejection(
        entityType: DatabaseService.pendingActionEntity,
        id: id,
      );

      await db.closeDatabase();
      await db.initDatabaseAt(path);

      expect(await db.countUnreadRejections(), 0);
      // Still refused, still listed -- only the interruption stops.
      final item = await onlyUpload();
      expect(item.state, UploadState.rejected);
      expect(item.acknowledged, isTrue);
    });

    test('a database from the shipped build upgrades without losing rows',
        () async {
      // Every phone in the field is on v5, which has no rejection_ack_at. The
      // migration has to add it to two tables that already hold a seller's
      // unsent work -- so this builds a v5-shaped database with rows in it,
      // opens it through the real service, and checks both.
      await db.closeDatabase();
      final legacyPath = p.join(dir.path, 'legacy_v5.db');
      final legacy = await databaseFactory.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (d, _) async {
            await d.execute('''
              CREATE TABLE pending_actions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                action_type TEXT NOT NULL,
                endpoint TEXT NOT NULL,
                label TEXT,
                request_id TEXT NOT NULL UNIQUE,
                payload TEXT NOT NULL,
                summary TEXT,
                server_id INTEGER,
                sync_status INTEGER DEFAULT 0,
                sync_error TEXT,
                sync_timestamp TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
              )
            ''');
            await d.execute('''
              CREATE TABLE sales (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                server_sale_id INTEGER,
                request_id TEXT UNIQUE,
                customer_id INTEGER,
                employee_id INTEGER NOT NULL,
                sale_time TEXT NOT NULL,
                total REAL DEFAULT 0,
                sync_status INTEGER DEFAULT 0,
                sync_error TEXT,
                sync_timestamp TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
              )
            ''');
            await d.execute('''
              CREATE TABLE sync_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entity_type TEXT NOT NULL,
                entity_id INTEGER NOT NULL,
                action TEXT NOT NULL,
                payload TEXT,
                priority INTEGER DEFAULT 0,
                retry_count INTEGER DEFAULT 0,
                max_retries INTEGER DEFAULT 5,
                sync_status INTEGER DEFAULT 0,
                error_message TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                last_attempted_at TEXT
              )
            ''');
          },
        ),
      );
      // A refusal the seller was already carrying when the update landed.
      await legacy.insert('pending_actions', {
        'action_type': 'expense',
        'endpoint': 'expenses/create',
        'label': 'Expense',
        'request_id': 'legacy-key',
        'payload': '{"amount":900}',
        'summary': 'Diesel',
        'sync_status': DatabaseService.syncStatusFailed,
        'sync_error': 'Invalid category ID',
        'created_at': DateTime.now().toIso8601String(),
      });
      await legacy.insert('sync_queue', {
        'entity_type': DatabaseService.pendingActionEntity,
        'entity_id': 1,
        'action': 'create',
        'sync_status': DatabaseService.syncStatusFailed,
        'error_message': 'Invalid category ID',
      });
      await legacy.close();

      // The update.
      await db.initDatabaseAt(legacyPath);

      // The row is still there, still refused, still carrying the reason --
      // and now countable as unread, which is the point of the migration.
      final merged = PendingUpload.merge(
        sales: await db.getUnsyncedSales(),
        actions: await db.getUnsyncedActions(),
      );
      expect(merged, hasLength(1));
      expect(merged.single.state, UploadState.rejected);
      expect(merged.single.reason, 'Invalid category ID');
      expect(merged.single.acknowledged, isFalse);
      expect(await db.countUnreadRejections(), 1);

      // And it can be acted on, which is what would fail if the column were
      // missing rather than merely null.
      await db.acknowledgeRejection(
        entityType: DatabaseService.pendingActionEntity,
        id: 1,
      );
      expect(await db.countUnreadRejections(), 0);
    });

    test('a discarded record stays discarded after a restart', () async {
      final id = await queueExpense(requestId: 'restart-key-3');
      await db.updateSyncQueueStatus(
        (await queueRowFor(id))['id'] as int,
        DatabaseService.syncStatusFailed,
        error: 'Refused',
      );
      await db.updatePendingActionStatus(
        id,
        DatabaseService.syncStatusFailed,
        error: 'Refused',
      );
      await db.discardRejected(
        entityType: DatabaseService.pendingActionEntity,
        id: id,
      );

      await db.closeDatabase();
      await db.initDatabaseAt(path);

      expect(await db.countUnreadRejections(), 0);
      expect(
        await db.getPendingSyncItems(
          entityType: DatabaseService.pendingActionEntity,
        ),
        isEmpty,
      );
      expect(
        (await db.getPendingAction(id))!['sync_status'],
        DatabaseService.syncStatusDiscarded,
      );
    });
  });
}
