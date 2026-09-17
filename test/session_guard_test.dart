import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/services/session_guard.dart';

void main() {
  setUp(SessionGuard.disarm);

  test('a 401 before any session begins is ignored', () {
    SessionGuard.reportUnauthorized(hadToken: true);
    expect(SessionGuard.expired.value, isFalse);
  });

  test('a refused sign-in does not end the session', () {
    SessionGuard.arm();
    // The login call carries no token: this is a wrong password, and the
    // login screen must be left to say so.
    SessionGuard.reportUnauthorized(hadToken: false);
    expect(SessionGuard.expired.value, isFalse);
  });

  test('a 401 on a request that carried a token ends the session', () {
    SessionGuard.arm();
    SessionGuard.reportUnauthorized(hadToken: true);
    expect(SessionGuard.expired.value, isTrue);
  });

  test('signing out disarms it, so trailing 401s raise nothing', () {
    SessionGuard.arm();
    SessionGuard.disarm();
    SessionGuard.reportUnauthorized(hadToken: true);
    expect(SessionGuard.expired.value, isFalse);
  });

  test('it fires once, so a burst of 401s is one sign-out', () {
    SessionGuard.arm();
    var notifications = 0;
    void count() => notifications++;
    SessionGuard.expired.addListener(count);
    addTearDown(() => SessionGuard.expired.removeListener(count));

    SessionGuard.reportUnauthorized(hadToken: true);
    SessionGuard.reportUnauthorized(hadToken: true);
    SessionGuard.reportUnauthorized(hadToken: true);

    expect(notifications, 1);
  });
}
