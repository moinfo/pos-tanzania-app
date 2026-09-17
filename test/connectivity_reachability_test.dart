import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/providers/connectivity_provider.dart';

/// The badge used to track the RADIO, so it read ONLINE while every request
/// failed -- a van on a bar of signal that carries nothing, a shop wifi whose
/// uplink is down, a captive portal. A seller was told to check a connection
/// that was fine.
void main() {
  group('online means the server answered, not that the radio is up', () {
    test('untested with signal reads online, rather than accusing the network',
        () {
      final c = ConnectivityProvider();
      expect(c.isOnline, isTrue);
      expect(c.serverUnreachable, isFalse);
    });

    test('a request that nobody answered takes it offline', () {
      final c = ConnectivityProvider()..reportServerReachable(false);
      expect(c.isOnline, isFalse);
      expect(c.isOffline, isTrue);
    });

    test('radio up but server silent is its own state, said differently', () {
      final c = ConnectivityProvider()..reportServerReachable(false);
      // Not "no internet" -- the internet is fine and telling the seller to
      // check it sends them to fix something that is not broken.
      expect(c.serverUnreachable, isTrue);
    });

    test('any answer counts, including a refusal', () {
      final c = ConnectivityProvider()..reportServerReachable(false);
      expect(c.isOnline, isFalse);
      // A 401 or a 500 still proves the server is there.
      c.reportServerReachable(true);
      expect(c.isOnline, isTrue);
      expect(c.serverUnreachable, isFalse);
    });

    test('it only notifies when the answer actually changes', () {
      var notifications = 0;
      final c = ConnectivityProvider()..addListener(() => notifications++);

      c.reportServerReachable(false);
      expect(notifications, 1);

      // Every failing request in a dead spot must not rebuild the tree.
      c.reportServerReachable(false);
      c.reportServerReachable(false);
      expect(notifications, 1);

      c.reportServerReachable(true);
      expect(notifications, 2);
    });

    test('losing the radio is offline whatever the last request proved', () {
      final c = ConnectivityProvider()..reportServerReachable(true);
      c.applyConnectivityResult(ConnectivityResult.none);
      expect(c.isOnline, isFalse);
    });

    test('a new radio forgets what the old one proved', () {
      final c = ConnectivityProvider()..reportServerReachable(false);
      expect(c.isOnline, isFalse);

      // Walking from a dead shop wifi onto mobile data must not keep insisting
      // the server is unreachable; the next real request settles it.
      c.applyConnectivityResult(ConnectivityResult.mobile);
      expect(c.isOnline, isTrue);
      expect(c.serverUnreachable, isFalse);
    });
  });

  /// The badge only knows what the request layer tells it, so every path that
  /// talks to the server has to report. _cachedGet did not: it builds its own
  /// ApiResponse instead of going through _handleResponse, so a screen whose
  /// loaders were all cached left the badge on its last known value. That grows
  /// worse the more endpoints get cached, which is the direction the app is
  /// moving -- hence a guard rather than a one-off fix.
  ///
  /// Read from source because ApiService._http is a static final with no seam
  /// to inject a stub through.
  group('every request path reports what it learned about the server', () {
    String cachedGetBody() {
      final source = File('lib/services/api_service.dart').readAsStringSync();
      final start = source.indexOf('Future<ApiResponse<T>> _cachedGet<T>(');
      expect(start, isNot(-1), reason: '_cachedGet has been renamed or removed');
      final end = source.indexOf('\n  /// A stable cache key', start);
      return source.substring(start, end == -1 ? start + 3000 : end);
    }

    test('a cached read reports the server as reachable when it answers', () {
      expect(cachedGetBody(), contains('_reportReachable(true)'),
          reason: 'A cached endpoint that answers must mark the server up, or '
              'the badge stays stuck showing an outage that has ended.');
    });

    test('a cached read reports what its failure means for the server', () {
      // It used to hard-code "unreachable" for anything thrown. A parse
      // failure on a 502 page is the server answering badly, not the network
      // being down, so the verdict now comes from the exception itself --
      // which is what stopped the app announcing an outage on a phone with
      // working data.
      expect(cachedGetBody(), contains('_reportFailure(e)'),
          reason: 'A cached endpoint that could not complete must still tell '
              'the badge what happened, or the app reads ONLINE while showing '
              'yesterday rows.');
    });

    test('only transport failures are reported as the server being down', () {
      final source = File('lib/services/api_service.dart').readAsStringSync();
      expect(source, contains('static bool _reportFailure(Object e)'),
          reason: 'The single place that decides reachability from a caught '
              'exception has been renamed or removed.');
      expect(source, isNot(contains('_reportReachable(false)')),
          reason: 'Reporting the server down without looking at the exception '
              'is how a JSON parse failure came to read as "no connection".');
    });
  });
}
