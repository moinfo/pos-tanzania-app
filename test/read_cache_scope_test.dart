import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/providers/auth_provider.dart';
import 'package:pos_tanzania_mobile/services/read_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Who is allowed to see a saved copy.
///
/// This is a correctness property, not a cache-hit-rate one. Two sellers share
/// a phone in a lot of these shops and an approval inbox is per-person, so the
/// second person to sign in must never open the app to the first person's
/// queue — they would act on decisions that were never theirs to make.
///
/// The bug these pin down was found on a device: the scope was resolved once
/// and memoised for the life of the process, and nothing invalidated it at
/// sign-in. A scope resolved on the login screen, before anyone had
/// authenticated, was still in force afterwards, and one user was shown a
/// credit-limit list written by another.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    // A fresh database file per test, so one test's rows cannot answer for
    // another's.
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/pos_read_cache.db',
    );
  });

  Future<ReadCache> cacheSignedInAs(String? userId) async {
    SharedPreferences.setMockInitialValues(
      userId == null ? {} : {AuthProvider.activeUserIdKey: userId},
    );
    return ReadCache.newForTest();
  }

  test('a saved copy comes back for the user who saved it', () async {
    final cache = await cacheSignedInAs('1');
    await cache.write('/approvals/pending', {'approvals': []});

    final read = await cache.read('/approvals/pending');
    expect(read, isNotNull);
    expect(read!.payload, {'approvals': []});
    await cache.close();
  });

  test('a different user is never served the first user\'s rows', () async {
    final asAdmin = await cacheSignedInAs('1');
    await asAdmin.write('/approvals/pending', {'approvals': ['admins']});
    await asAdmin.close();

    // Same device, same key, different person signed in.
    final asSeller = await cacheSignedInAs('42');
    expect(await asSeller.read('/approvals/pending'), isNull);
    await asSeller.close();
  });

  test('signing in as someone else purges the previous user entirely', () async {
    final asAdmin = await cacheSignedInAs('1');
    await asAdmin.write('/approvals/pending', {'a': 1});
    await asAdmin.write('/customer_credit_limits/requests', {'b': 2});
    await asAdmin.close();

    final asSeller = await cacheSignedInAs('42');
    // Touch the cache once as the new user, which is what triggers the purge.
    await asSeller.write('/items', {'c': 3});
    await asSeller.close();

    // Back to the first user: their rows are gone, not merely hidden. Leaving
    // them on disk would mean a third party with the handset could still read
    // one seller's customer list.
    final backAsAdmin = await cacheSignedInAs('1');
    expect(await backAsAdmin.read('/approvals/pending'), isNull);
    expect(await backAsAdmin.read('/customer_credit_limits/requests'), isNull);
    await backAsAdmin.close();
  });

  test('a scope resolved before sign-in does not outlive it', () async {
    // The exact shape of the device bug. The app cold-starts with no network,
    // lands on the login screen with nobody signed in, something touches the
    // cache, and only then does someone authenticate.
    final cache = await cacheSignedInAs(null);
    await cache.write('/dashboard', {'anon': true});
    expect(await cache.read('/dashboard'), isNotNull);

    // Now a real sign-in happens, in the SAME process and on the SAME
    // instance. The scope must re-resolve rather than stay pinned to 'anon'.
    SharedPreferences.setMockInitialValues({AuthProvider.activeUserIdKey: '1'});
    expect(await cache.read('/dashboard'), isNull);
    await cache.close();
  });

  test('a copy past its horizon is refused rather than shown', () async {
    final cache = await cacheSignedInAs('1');
    await cache.write('/approvals/pending', {'approvals': []});

    // Fresh enough for a queue, so it is served.
    expect(await cache.read('/approvals/pending', maxAge: CacheAge.queue),
        isNotNull);
    // Nothing is fresh enough for a zero horizon, so it is not.
    expect(
      await cache.read('/approvals/pending', maxAge: Duration.zero),
      isNull,
      reason: 'a stale approval queue is worse than an empty one',
    );
    await cache.close();
  });

  test('a later write replaces the earlier copy rather than stacking', () async {
    final cache = await cacheSignedInAs('1');
    await cache.write('/items', {'items': [1]});
    await cache.write('/items', {'items': [1, 2]});

    final read = await cache.read('/items');
    expect(read!.payload, {'items': [1, 2]});
    await cache.close();
  });

  test('clearScope forgets this user without touching the file', () async {
    final cache = await cacheSignedInAs('1');
    await cache.write('/items', {'items': [1]});
    await cache.clearScope();
    expect(await cache.read('/items'), isNull);
    await cache.close();
  });

  group('knownKeys, which is what the background warm replays', () {
    test('returns the keys this user saved, without the scope prefix', () async {
      final cache = await cacheSignedInAs('1');
      await cache.write('/items?limit=100&location_id=3', {'items': []});
      await cache.write('/customers?limit=100', {'customers': []});

      final keys = await cache.knownKeys();

      // The prefix has to come off: the warm feeds these straight back to
      // ApiService.refreshCachedKey, which rebuilds a URL from them. A leaked
      // "leruma|1|" would produce a request to a path that does not exist.
      expect(keys, contains('/items?limit=100&location_id=3'));
      expect(keys, contains('/customers?limit=100'));
      expect(keys.every((k) => k.startsWith('/')), isTrue);
    });

    test("another user's keys are not offered for replay", () async {
      final first = await cacheSignedInAs('1');
      await first.write('/approvals/pending', {'approvals': []});

      final second = await cacheSignedInAs('2');
      await second.write('/items?limit=100', {'items': []});

      // Replaying a key belonging to somebody else would refetch and re-save
      // it under the new user -- quietly importing the first person's queue
      // into the second person's app.
      final keys = await second.knownKeys();
      expect(keys, isNot(contains('/approvals/pending')));
    });

    test('nothing saved yet yields an empty list, not an error', () async {
      final cache = await cacheSignedInAs('7');
      expect(await cache.knownKeys(), isEmpty);
    });
  });
}
