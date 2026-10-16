import 'package:flutter/widgets.dart';

import 'curved_bottom_navigation.dart';

/// Remembers which side-menu entry opened the screen on top, so that screen's
/// bottom navigation bar can show that entry's icon in the centre notch.
///
/// The drawer calls [announce] just before it pushes a screen. The first
/// bottom bar that builds afterwards [claim]s it for its own route, so the icon
/// stays with that screen only: pop back, or open a screen by some other path,
/// and the bar is back to normal. An announcement nobody claims within two
/// seconds is dropped (some screens carry no bottom bar).
class NavActive {
  NavActive._();

  static CurvedNavItem? _pending;
  static DateTime? _announcedAt;
  static final Expando<CurvedNavItem> _byRoute = Expando<CurvedNavItem>();

  static void announce(IconData icon, String label) {
    _pending = CurvedNavItem(icon: icon, label: label);
    _announcedAt = DateTime.now();
  }

  /// The side-menu entry that opened [route], or null.
  static CurvedNavItem? claim(Route<dynamic>? route) {
    if (route == null) return null;
    final existing = _byRoute[route];
    if (existing != null) return existing;

    final pending = _pending;
    final at = _announcedAt;
    if (pending == null || at == null) return null;
    _pending = null;
    _announcedAt = null;
    if (DateTime.now().difference(at) > const Duration(seconds: 2)) return null;

    _byRoute[route] = pending;
    return pending;
  }
}
