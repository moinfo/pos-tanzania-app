import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Customer portal's own SW/EN switch -- self-contained (a plain
/// ValueNotifier, not app-wide Provider state) so it doesn't depend on
/// where main.dart's provider tree is rooted, matching how
/// CustomerApiService already keeps the whole portal feature
/// self-contained. English is the default (matching the portal's original
/// auth screens, all written in English); Swahili is the toggle.
class PortalLocale {
  PortalLocale._();
  static final PortalLocale instance = PortalLocale._();

  static const _prefsKey = 'portal_language';

  final ValueNotifier<String> language = ValueNotifier<String>('en');
  bool _loaded = false;

  bool get isSwahili => language.value == 'sw';

  /// Call once before the portal's first screen builds (its login entry
  /// point) so the saved preference is in place before anything renders.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      language.value = prefs.getString(_prefsKey) ?? 'en';
    } catch (_) {
      // Storage unavailable -- keep the 'en' default rather than failing
      // the portal to load over a language preference.
    }
  }

  Future<void> toggle() async {
    language.value = language.value == 'en' ? 'sw' : 'en';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language.value);
    } catch (_) {
      // Preference just won't persist across app restarts -- not worth
      // failing the toggle itself over.
    }
  }
}
