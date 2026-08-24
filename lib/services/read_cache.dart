import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/api_response.dart';
import '../providers/auth_provider.dart';
import 'api_service.dart';

/// How long a saved copy of a list stays worth showing.
///
/// This is a judgement about the cost of being wrong, not about bandwidth.
/// A queue that changes hands minute to minute goes stale fast: showing a
/// seller an approval that a manager decided an hour ago sends them to argue
/// about a decision that has already been made. A supplier list barely moves
/// from one month to the next, so a week-old copy is still the truth.
///
/// Past the horizon the cache is not shown at all — the screen falls through
/// to the "nothing saved" state, which tells the user to connect. A blank
/// screen that says so is safer than a confident screen that is wrong.
class CacheAge {
  const CacheAge._();

  /// Queues that people act on. Short, because acting on a stale row wastes
  /// somebody's trip.
  static const Duration queue = Duration(hours: 6);

  /// Money that moved today: takings, expenses, payments, the dashboard.
  /// Useful for "what did I do this morning", misleading by tomorrow.
  static const Duration today = Duration(hours: 12);

  /// Reference lists people look things up in — customers, items, suppliers,
  /// the choices in a picker. These change slowly and a day-old copy still
  /// answers "what is this customer's phone number" correctly.
  static const Duration reference = Duration(days: 3);

  /// History that is finished and cannot change retroactively.
  static const Duration ledger = Duration(days: 7);
}

/// One saved response, with the time it was taken.
class CachedRead {
  const CachedRead({required this.payload, required this.fetchedAt});

  /// The decoded JSON that the screen originally parsed.
  final dynamic payload;

  /// When this copy was taken off the server.
  final DateTime fetchedAt;

  Duration get age => DateTime.now().difference(fetchedAt);

  bool isFresherThan(Duration horizon) => age <= horizon;

  /// See [describeCacheAge].
  String get describeAge => describeCacheAge(fetchedAt);
}

/// "just now" / "14 minutes ago" / "3 hours ago" / "2 days ago".
///
/// Deliberately coarse. A seller does not need the second; they need to know
/// whether what they are looking at is roughly now or roughly yesterday.
String describeCacheAge(DateTime fetchedAt) {
  final a = DateTime.now().difference(fetchedAt);
  if (a.inMinutes < 1) return 'just now';
  if (a.inMinutes < 60) {
    return '${a.inMinutes} minute${a.inMinutes == 1 ? '' : 's'} ago';
  }
  if (a.inHours < 24) {
    return '${a.inHours} hour${a.inHours == 1 ? '' : 's'} ago';
  }
  return '${a.inDays} day${a.inDays == 1 ? '' : 's'} ago';
}

/// A read-only copy of the last successful answer for each list screen, so a
/// screen can OPEN with something on it when the server cannot be reached.
///
/// Deliberately its own database file, separate from the offline sales
/// database in [DatabaseService]. That one is the write path: queued sales,
/// the sync queue, the master data a sale needs to be composed at all. Its
/// schema is versioned and migrated. This is throwaway display data — if it is
/// lost, or its shape changes because an endpoint changed, the right answer is
/// to drop it and refetch, never to migrate it. Keeping the two apart means a
/// change here can never put a queued sale at risk.
///
/// Nothing here is ever uploaded, and nothing here is a source of truth. Every
/// row is replaced wholesale by the next successful online load.
class ReadCache {
  ReadCache._();

  static final ReadCache instance = ReadCache._();

  static const String _dbName = 'pos_read_cache.db';
  static const int _dbVersion = 1;

  Database? _db;
  String? _scope;

  @visibleForTesting
  static ReadCache newForTest() => ReadCache._();

  /// Rows are namespaced by client and by signed-in user, and the moment that
  /// namespace changes everything belonging to anyone else is deleted.
  ///
  /// Two sellers share a phone in a lot of these shops and an approval inbox is
  /// per-person, so this is a correctness property, not an optimisation: the
  /// second person to sign in must never open the app to the first person's
  /// queue. Namespacing alone was not enough to guarantee it. The scope used to
  /// be resolved once and memoised for the life of the process, and nothing
  /// invalidated it at sign-in — so a scope resolved on the login screen, before
  /// anyone had authenticated, was still in force after someone had. On device
  /// that showed one user a credit-limit list written by another.
  ///
  /// Two changes fix it. The scope is re-resolved on every access rather than
  /// pinned; and when it changes, rows from every other scope are dropped. That
  /// means at most one person's cache exists on the device at a time. Two users
  /// alternating on one phone therefore lose their cache each swap, which is the
  /// right trade — a cache miss costs a refresh, the alternative costs trust.
  Future<String> _currentScope() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(AuthProvider.activeUserIdKey) ?? 'anon';
    final clientId = ApiService.currentClient?.id ?? 'unknown';
    final scope = '$clientId|$userId';

    // Only remember the scope once the purge has actually run. If the delete
    // fails, the next access retries it rather than settling into a state where
    // another user's rows are present and nothing will ever remove them.
    if (_scope != scope && await _dropForeignScopes(scope)) {
      _scope = scope;
    }
    return scope;
  }

  /// Delete every row that does not belong to [scope].
  ///
  /// Deliberately a denylist ("not mine") rather than an allowlist of known
  /// previous users: a row whose owner cannot be established is a row that
  /// must not be shown.
  Future<bool> _dropForeignScopes(String scope) async {
    final db = await _open();
    if (db == null) return false;
    try {
      final removed = await db.delete(
        'read_cache',
        where: 'cache_key NOT LIKE ?',
        whereArgs: ['$scope|%'],
      );
      if (removed > 0) {
        debugPrint('ReadCache: dropped $removed row(s) from another scope');
      }
      return true;
    } catch (e) {
      debugPrint('ReadCache: could not drop foreign scopes: $e');
      return false;
    }
  }

  /// Forget the resolved scope, forcing the next access to re-check who is
  /// signed in. Calling this is no longer required for correctness — the scope
  /// is re-resolved every time — but it is kept for an explicit sign-out.
  void invalidateScope() => _scope = null;

  Future<Database?> _open() async {
    if (_db != null) return _db;
    try {
      final path = join(await getDatabasesPath(), _dbName);
      _db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE read_cache (
              cache_key TEXT PRIMARY KEY,
              payload TEXT NOT NULL,
              fetched_at TEXT NOT NULL
            )
          ''');
        },
      );
      return _db;
    } catch (e) {
      // A cache that cannot open must never take a screen down with it. The
      // screen falls through to "nothing saved", which is honest.
      debugPrint('ReadCache: could not open cache database: $e');
      return null;
    }
  }

  /// Save the payload of a successful load under [key].
  Future<void> write(String key, dynamic payload) async {
    final db = await _open();
    if (db == null) return;
    try {
      await db.insert(
        'read_cache',
        {
          'cache_key': '${await _currentScope()}|$key',
          'payload': jsonEncode(payload),
          'fetched_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _prune(db);
    } catch (e) {
      debugPrint('ReadCache: could not save "$key": $e');
    }
  }

  /// Keep only the most recently written [_maxRows] entries.
  ///
  /// Keys carry the query string, so a screen that filters by date range or
  /// paginates writes a new row per variation. Left alone that grows without
  /// limit on a device that is never reinstalled. Dropping the oldest is the
  /// right eviction here: the row a seller wants offline is the one they were
  /// looking at last, and everything in this table is reconstructible.
  static const int _maxRows = 300;

  Future<void> _prune(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM read_cache'),
        ) ??
        0;
    if (count <= _maxRows) return;
    await db.rawDelete(
      'DELETE FROM read_cache WHERE cache_key IN ('
      'SELECT cache_key FROM read_cache ORDER BY fetched_at ASC LIMIT ?)',
      [count - _maxRows],
    );
  }

  /// The saved copy for [key], or null if there is none or it cannot be read.
  ///
  /// Pass [maxAge] to refuse a copy that is too old to be trusted; the caller
  /// then renders the "nothing saved" state rather than a misleading list.
  Future<CachedRead?> read(String key, {Duration? maxAge}) async {
    final db = await _open();
    if (db == null) return null;
    try {
      final rows = await db.query(
        'read_cache',
        where: 'cache_key = ?',
        whereArgs: ['${await _currentScope()}|$key'],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final fetchedAt = DateTime.tryParse(rows.first['fetched_at'] as String? ?? '');
      if (fetchedAt == null) return null;

      final entry = CachedRead(
        payload: jsonDecode(rows.first['payload'] as String),
        fetchedAt: fetchedAt,
      );
      if (maxAge != null && !entry.isFresherThan(maxAge)) return null;
      return entry;
    } catch (e) {
      // A payload whose shape no longer parses is not worth rescuing.
      debugPrint('ReadCache: could not read "$key": $e');
      return null;
    }
  }

  /// Forget everything saved for the signed-in user on this client.
  Future<void> clearScope() async {
    final db = await _open();
    if (db == null) return;
    try {
      await db.delete(
        'read_cache',
        where: 'cache_key LIKE ?',
        whereArgs: ['${await _currentScope()}|%'],
      );
    } catch (e) {
      debugPrint('ReadCache: could not clear: $e');
    }
  }

  @visibleForTesting
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _scope = null;
  }
}

/// Was this failure the network, or was it the server saying no?
///
/// The distinction matters and is easy to get wrong here, because
/// [ApiService] does not throw on a transport failure — it catches
/// SocketException and friends and returns an ERROR RESPONSE instead. Every
/// `catch (e)` offline fallback written against it was therefore dead code
/// that never ran once. Ask the response, not the exception.
///
/// The tell is a null [ApiResponse.statusCode]: a response parsed from an
/// actual HTTP reply always carries the code the server sent, so a missing one
/// means no reply arrived. The message check is a second gate, so a
/// hand-rolled validation error that happens to omit the status code is not
/// mistaken for the network being down.
bool isTransportFailure(ApiResponse<dynamic> response) {
  if (response.isSuccess) return false;
  if (response.statusCode != null) return false;

  // The RAW text, not the user-facing one. ApiResponse.error translates
  // transport noise into "No connection. Check your internet and try again."
  // before any screen can leak it, which would defeat a match on `message`.
  final message = response.diagnostic.toLowerCase();
  const tells = [
    'socketexception',
    'clientexception',
    'failed host lookup',
    'network error',
    'network is unreachable',
    'connection error',
    'connection timeout',
    'connection refused',
    'connection closed',
    'connection reset',
    'timeoutexception',
    'handshakeexception',
    'unable to connect',
    'software caused connection abort',
    // The translated wording, for a response built from an already-friendly
    // message (so the classification survives a round trip).
    'no connection. check your internet',
    'could not connect',
  ];
  return tells.any(message.contains);
}
