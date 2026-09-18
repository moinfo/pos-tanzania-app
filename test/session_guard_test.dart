import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:pos_tanzania_mobile/services/api_service.dart';
import 'package:pos_tanzania_mobile/services/session_guard.dart';
import 'package:pos_tanzania_mobile/services/token_refresher.dart';

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

  // Reading the expiry out of the token is what decides when to renew; a
  // misread would either renew on every request or never renew at all.
  group('reading a token\'s expiry', () {
    String tokenExpiringAt(int epochSeconds) {
      String seg(Object o) => base64Url
          .encode(utf8.encode(json.encode(o)))
          .replaceAll('=', '');
      return '${seg({'alg': 'HS256'})}.'
          '${seg({'sub': 1, 'exp': epochSeconds})}.signature-not-checked-here';
    }

    test('the exp claim is read back exactly', () {
      final deadline =
          DateTime.now().add(const Duration(hours: 3)).toUtc();
      final seconds = deadline.millisecondsSinceEpoch ~/ 1000;

      final read = TokenRefresher.expiryOf(tokenExpiringAt(seconds));

      expect(read, isNotNull);
      expect(read!.millisecondsSinceEpoch ~/ 1000, seconds);
    });

    test('an unreadable token yields null rather than throwing', () {
      expect(TokenRefresher.expiryOf('not-a-jwt'), isNull);
      expect(TokenRefresher.expiryOf('only.two'), isNull);
      expect(TokenRefresher.expiryOf('a.!!!not-base64!!!.c'), isNull);
    });

    test('a token with no exp claim yields null', () {
      final noExp = base64Url
          .encode(utf8.encode(json.encode({'sub': 1})))
          .replaceAll('=', '');
      expect(TokenRefresher.expiryOf('header.$noExp.sig'), isNull);
    });
  });

  // A 401 may only clear the token it refused. Reading that token back off the
  // request is what lets a stale answer be told apart from a live one.
  group('reading the token a request carried', () {
    test('a bearer token is read back exactly', () {
      expect(ApiService.bearerOf({'Authorization': 'Bearer abc.def.ghi'}),
          'abc.def.ghi');
    });

    test('the header name is matched case-insensitively', () {
      expect(ApiService.bearerOf({'authorization': 'Bearer xyz'}), 'xyz');
    });

    test('no header, an empty one, or "Bearer null" carried no token', () {
      expect(ApiService.bearerOf(null), isNull);
      expect(ApiService.bearerOf({'Accept': 'application/json'}), isNull);
      expect(ApiService.bearerOf({'Authorization': 'Bearer '}), isNull);
      expect(ApiService.bearerOf({'Authorization': 'Bearer null'}), isNull);
    });
  });
}
