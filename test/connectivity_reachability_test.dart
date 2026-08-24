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
}
