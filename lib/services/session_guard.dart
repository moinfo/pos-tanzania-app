import 'package:flutter/foundation.dart';

/// Raised the moment the server stops accepting this session.
///
/// WHY THIS IS GLOBAL AND NOT PER CALL SITE
/// ----------------------------------------
/// Thirty-three request helpers in ApiService build their own error branch and
/// never notice a 401 -- the dashboard among them, which is why an expired
/// token surfaced as "Authorization token required" with a Try again button
/// that could only fail again. Asking every one of those to remember is the
/// arrangement that already failed; the shared HTTP client sees all of them,
/// so the check lives there instead, exactly like the minimum-version gate.
///
/// WHAT COUNTS AS A DEAD SESSION
/// -----------------------------
/// A 401 answering a request that CARRIED a token. A 401 with no token on the
/// request is a sign-in being refused -- a wrong password -- and must leave the
/// login screen alone to say so.
///
/// [arm] is what keeps cold start quiet: the splash verifies a stored token and
/// a refusal there already routes to login on its own, so the takeover only
/// becomes live once a session is actually running.
class SessionGuard {
  SessionGuard._();

  /// Flips to true once, when a live session is refused. Never cleared: the
  /// only way out is signing in again, which rebuilds the app's state anyway.
  static final ValueNotifier<bool> expired = ValueNotifier<bool>(false);

  static bool _armed = false;

  /// Called when a session begins, so 401s start counting.
  static void arm() => _armed = true;

  /// Called on sign-out, so the screen behind a deliberate logout cannot raise
  /// the takeover on top of it.
  static void disarm() {
    _armed = false;
    expired.value = false;
  }

  /// Told about every 401 the shared client sees.
  ///
  /// [hadToken] is whether the refused request actually carried one.
  static void reportUnauthorized({required bool hadToken}) {
    if (!_armed || !hadToken || expired.value) return;
    debugPrint('SessionGuard: server refused this session - signing out');
    expired.value = true;
  }
}
