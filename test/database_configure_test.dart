import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opening the offline database must succeed, and must actually end up in WAL.
///
/// This guards a bug that took the whole app down on iOS: `onConfigure` ran
///
///     await db.execute('PRAGMA journal_mode = WAL');
///
/// but that PRAGMA ANSWERS with the mode it settled on ("wal"), and a statement
/// that returns a row is not what execute() is for. The Darwin implementation
/// of sqflite surfaces that row as DatabaseException(Code=0 "not an error"),
/// which is thrown straight out of openDatabase -- so the database never
/// opened, OfflineProvider's initialise never returned, and the app sat on the
/// splash screen with a spinner that never resolved. On a fresh install that
/// was every launch until the user force-quit and reopened.
///
/// Note why the existing tests did not catch it: they run on
/// sqflite_common_ffi, and the FFI backend tolerates a returning statement
/// passed to execute(). Only the iOS backend refuses. So this test cannot
/// reproduce the throw either -- what it CAN do is assert the outcome that the
/// wrong call silently failed to produce, which is the journal actually being
/// WAL. If someone rewrites this as execute() again, the pragma stops taking
/// effect and this test fails.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    tmp = await Directory.systemTemp.createTemp('pos_db_configure_test');
  });

  tearDown(() async {
    await DatabaseService.instance.closeDatabase();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('a brand new database opens without throwing', () async {
    final path = '${tmp.path}/fresh.db';
    expect(File(path).existsSync(), isFalse,
        reason: 'the point of this test is the FIRST open, which is the one '
            'that failed on device');

    final db = await DatabaseService.instance.initDatabaseAt(path);

    expect(db.isOpen, isTrue);
  });

  test('journal_mode is WAL, not the default rollback journal', () async {
    final db =
        await DatabaseService.instance.initDatabaseAt('${tmp.path}/wal.db');

    final rows = await db.rawQuery('PRAGMA journal_mode');
    final mode = rows.first.values.first.toString().toLowerCase();

    expect(mode, 'wal',
        reason: 'WAL is what lets a queued upload write while the till reads; '
            'if the pragma silently did nothing we are back to one exclusive '
            'writer lock and "database is locked" under contention');
  });

  test('foreign keys are on', () async {
    final db =
        await DatabaseService.instance.initDatabaseAt('${tmp.path}/fk.db');

    final rows = await db.rawQuery('PRAGMA foreign_keys');
    expect(rows.first.values.first.toString(), '1');
  });

  test('reopening an existing WAL database also succeeds', () async {
    final path = '${tmp.path}/reopen.db';

    await DatabaseService.instance.initDatabaseAt(path);
    await DatabaseService.instance.closeDatabase();

    // The second open takes the migration path rather than onCreate, and
    // re-runs onConfigure against a file that is already in WAL.
    final db = await DatabaseService.instance.initDatabaseAt(path);
    expect(db.isOpen, isTrue);

    final rows = await db.rawQuery('PRAGMA journal_mode');
    expect(rows.first.values.first.toString().toLowerCase(), 'wal');
  });
}
