import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/services/database_service.dart';
import 'package:pos_tanzania_mobile/services/offline_actions.dart';
import 'package:pos_tanzania_mobile/services/offline_submit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The queue that holds every CREATE a seller or clerk makes with no network.
///
/// What is being defended here is exactly one thing: an action must reach the
/// server ONCE. Not zero times, which loses a person's work, and not twice,
/// which puts money or stock in the books that never moved.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;

  setUp(() async {
    // A fresh in-memory database per test, built by the real schema, so these
    // tests fail if the migration or the table definition drifts.
    databaseFactory = databaseFactoryFfi;
    db = DatabaseService.instance;
    await db.closeDatabase();
    await db.initDatabaseAt(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.closeDatabase();
  });

  Future<int> queueExpense({
    required String requestId,
    double amount = 5000,
  }) =>
      db.queueAction(
        actionType: OfflineAction.expense.type,
        endpoint: OfflineAction.expense.endpoint,
        label: OfflineAction.expense.label,
        requestId: requestId,
        payload: {'amount': amount, 'description': 'Fuel'},
        summary: 'Fuel',
      );

  group('the queue keeps what it is given', () {
    test('a queued action stores its key, endpoint and exact body', () async {
      final id = await queueExpense(requestId: 'key-1');

      final row = await db.getPendingAction(id);
      expect(row, isNotNull);
      expect(row!['request_id'], 'key-1');
      expect(row['endpoint'], 'expenses/create');
      expect(row['action_type'], 'expense');

      // The body is stored verbatim. The upload re-sends THIS, rather than
      // rebuilding the call from a model that may have moved on since.
      expect(
        jsonDecode(row['payload'] as String),
        {'amount': 5000, 'description': 'Fuel'},
      );
    });

    test('queueing files a matching sync queue row for the uploader', () async {
      final id = await queueExpense(requestId: 'key-2');

      final queued = await db.getPendingSyncItems(
        entityType: DatabaseService.pendingActionEntity,
      );
      expect(queued, hasLength(1));
      expect(queued.single['entity_id'], id);
    });

    test('an action with no key is refused rather than queued', () async {
      // Uploading without a key risks a duplicate, and a duplicate is worse
      // than something that waits for a person.
      await expectLater(
        queueExpense(requestId: ''),
        throwsA(isA<ArgumentError>()),
      );

      expect(await db.getUnsyncedActionCounts(), {'pending': 0, 'failed': 0});
    });
  });

  group('exactly once', () {
    test('the same key cannot enter the queue twice', () async {
      await queueExpense(requestId: 'key-3');

      // A caller reusing one key across two actions is a bug. Failing here --
      // locally, before anything is promised to the user -- is far better than
      // the server quietly replaying the first action's answer for the second.
      await expectLater(queueExpense(requestId: 'key-3'), throwsException);

      final counts = await db.getUnsyncedActionCounts();
      expect(counts['pending'], 1, reason: 'the replay must not add a row');
    });

    test('a replayed key leaves the queue depth unchanged', () async {
      await queueExpense(requestId: 'replay-me');
      final before = (await db.getUnsyncedActions()).length;

      // Simulate the retry the sync service would make after a timeout: same
      // key, same body. The row count is the thing that must not move.
      try {
        await queueExpense(requestId: 'replay-me');
      } catch (_) {
        // expected
      }

      expect((await db.getUnsyncedActions()).length, before);
    });

    test('two genuinely different actions each get their own row', () async {
      await queueExpense(requestId: 'key-a', amount: 5000);
      await queueExpense(requestId: 'key-b', amount: 5000);

      // Same amount, same description, two separate fuel expenses on one day.
      // Different keys, so neither is suppressed as a replay of the other.
      expect((await db.getUnsyncedActionCounts())['pending'], 2);
    });
  });

  group('what a person is shown', () {
    test('an uploaded action drops out of the waiting list', () async {
      final id = await queueExpense(requestId: 'key-4');

      await db.updatePendingActionStatus(
        id,
        DatabaseService.syncStatusSynced,
        serverId: 77,
      );

      expect(await db.getUnsyncedActions(), isEmpty);
      expect(await db.getUnsyncedActionCounts(), {'pending': 0, 'failed': 0});
    });

    test('a refused action is kept, counted as failed, and says why', () async {
      final id = await queueExpense(requestId: 'key-5');

      await db.updatePendingActionStatus(
        id,
        DatabaseService.syncStatusFailed,
        error: 'That expense category no longer exists',
      );

      final counts = await db.getUnsyncedActionCounts();
      expect(counts['failed'], 1);
      expect(counts['pending'], 0);

      final rows = await db.getUnsyncedActions();
      expect(rows.single['label'], 'Expense');
      expect(rows.single['summary'], 'Fuel');
      expect(rows.single['sync_error'], contains('no longer exists'));
    });

    test('a cache clear keeps what is still owed to the server', () async {
      final uploaded = await queueExpense(requestId: 'key-6');
      await queueExpense(requestId: 'key-7');
      await db.updatePendingActionStatus(
          uploaded, DatabaseService.syncStatusSynced);

      await db.clearSyncedData();

      // The queued one is the only copy there is; only the uploaded one goes.
      final rows = await db.getUnsyncedActions();
      expect(rows, hasLength(1));
      expect(rows.single['request_id'], 'key-7');
    });
  });

  group('the catalogue', () {
    test('every action type is unique and resolvable', () {
      final types = OfflineAction.values.map((a) => a.type).toList();
      expect(types.toSet().length, types.length,
          reason: 'two actions sharing a type would upload to the wrong place');

      for (final action in OfflineAction.values) {
        // A stored row resolves its endpoint through byType. An action missing
        // from `values` is one the queue can never upload.
        expect(OfflineAction.byType(action.type), same(action));
        expect(action.endpoint, isNotEmpty);
        expect(action.label, isNotEmpty);
      }
    });

    test('an unknown type resolves to nothing rather than a guess', () {
      expect(OfflineAction.byType('something_a_later_build_added'), isNull);
    });
  });

  group('online-only refusals', () {
    test('name the action and say nothing was saved', () {
      final message = OnlineOnly.message(OnlineOnly.processReturn);

      expect(message, contains('Returning a sale'));
      expect(message, contains('internet connection'));
      // The part that stops a person tapping again and again.
      expect(message, contains('Nothing was saved'));
      expect(message, isNot(contains('SocketException')));
    });

    test('editing and deleting are refused by the thing they target', () {
      expect(OnlineOnly.message(OnlineOnly.edit('expense')),
          startsWith('Editing this expense'));
      expect(OnlineOnly.message(OnlineOnly.remove('customer')),
          startsWith('Deleting this customer'));
    });
  });

  group('idempotency keys minted by a form', () {
    test('the same payload keeps its key, so a retry is a replay', () {
      final submitter = OfflineSubmitter();
      final payload = {'amount': 5000, 'description': 'Fuel'};

      final first = submitter.idFor(payload);
      final retry = submitter.idFor(Map<String, dynamic>.from(payload));

      expect(retry, first,
          reason: 'a Save tapped twice must not become two expenses');
    });

    test('an edited payload mints a new key', () {
      final submitter = OfflineSubmitter();

      final first = submitter.idFor({'amount': 5000});
      final edited = submitter.idFor({'amount': 6000});

      expect(edited, isNot(first),
          reason: 'a genuinely different record must not be '
              'suppressed as a replay of the first');
    });

    test('once settled, an identical entry is a new record', () {
      final submitter = OfflineSubmitter();
      final payload = {'amount': 5000};

      final first = submitter.idFor(payload);
      // The key now belongs to the accepted or queued row.
      submitter.release();
      final second = submitter.idFor(payload);

      expect(second, isNot(first),
          reason: 'two identical 5,000/= expenses on one day really do happen');
    });
  });
}
