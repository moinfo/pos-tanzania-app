import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Keeps the session alive so a seller is not signed out once a day.
///
/// The token lasts 24 hours. Before this existed nothing renewed it: the app
/// ran until the server refused it, and the seller had to type their password
/// again -- every day, usually mid-shift.
///
/// Two moments renew it, and they cover different failures:
///  * [refreshIfExpiringSoon], called while the app is in use, renews a token
///    with less than [_renewWhenLeft] to live. This is the normal path and it
///    means a working phone should never see a 401 at all.
///  * [refreshNow], called by the shared client when a request IS refused,
///    covers the phone that was switched off, asleep, or out of coverage when
///    the renewal was due. The server allows this for a bounded window past
///    expiry (JWT_Lib::$refresh_window); past it the session really is over
///    and SessionGuard signs out.
class TokenRefresher {
  TokenRefresher._();

  static final TokenRefresher instance = TokenRefresher._();

  final ApiService _api = ApiService();

  /// Renew once the token has less than this left. Comfortably longer than a
  /// shift, so a phone used at any point during the day renews without the
  /// seller noticing, and a phone left in a drawer over a weekend still has
  /// the server's grace window to fall back on.
  static const Duration _renewWhenLeft = Duration(hours: 8);

  /// The renewal in flight, if any.
  ///
  /// Every screen polls and a burst of parallel requests can all be refused at
  /// once; without this they would each mint a token and the last one to
  /// finish would win, invalidating the others' -- a self-inflicted logout.
  Future<bool>? _inFlight;

  /// When the current token dies, read from the token itself.
  ///
  /// The login response only says `expires_in`, a duration, so the only exact
  /// instant available is the `exp` claim in the JWT payload. It is plain
  /// base64url and needs no secret to read; the signature still protects it,
  /// because a token edited here would simply be refused by the server.
  static DateTime? expiryOf(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! int) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (e) {
      // A token we cannot read is not a reason to sign anyone out: the server
      // is the authority on whether it works.
      debugPrint('TokenRefresher: could not read expiry - $e');
      return null;
    }
  }

  /// Renew if the token is close to its end. Cheap to call often -- it reads
  /// the token locally and does nothing until the deadline is near.
  Future<void> refreshIfExpiringSoon() async {
    final token = await _api.getToken();
    if (token == null) return;

    final expiry = expiryOf(token);
    if (expiry == null) return;

    if (expiry.difference(DateTime.now()) > _renewWhenLeft) return;

    await refreshNow();
  }

  /// Ask the server for a new token now. Returns whether the session survived.
  Future<bool> refreshNow() => _inFlight ??= _refresh().whenComplete(() {
        _inFlight = null;
      });

  Future<bool> _refresh() async {
    final response = await _api.refreshToken();

    if (response.isSuccess && response.data?['token'] != null) {
      debugPrint('TokenRefresher: session renewed');
      return true;
    }

    // A refusal (the grace window has passed, or the account is gone) ends the
    // session. Anything without a status code is the network, and says nothing
    // about whether the session is still good -- so it is not treated as death.
    final refused = response.statusCode != null;
    debugPrint('TokenRefresher: renewal failed'
        '${refused ? ' (server refused: ${response.message})' : ' (offline)'}');
    return !refused;
  }
}
