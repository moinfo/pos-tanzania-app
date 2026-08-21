import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  /// Read once before the first frame by [preload], so a dark-mode user does
  /// not watch the app paint itself light and then flip.
  static ThemeMode? _initial;

  ThemeMode _themeMode = _initial ?? ThemeMode.light;

  /// True once the stored preference has been applied, either by [preload] or
  /// by the constructor's own load.
  bool _settled = _initial != null;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    if (!_settled) _loadThemeMode();
  }

  /// Load the saved mode ahead of `runApp`.
  ///
  /// Without this the provider starts on light and swaps to dark a frame or
  /// two later, which a dark-mode user sees as a white flash on every launch.
  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    _initial = (prefs.getBool(_themeKey) ?? false)
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();

    // An explicit setThemeMode/toggleTheme while this was in flight is the
    // user's choice and outranks what was on disk. Without this guard the
    // async load lands last and silently undoes it.
    if (_settled) return;

    _themeMode =
        (prefs.getBool(_themeKey) ?? false) ? ThemeMode.dark : ThemeMode.light;
    _settled = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _settled = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _settled = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, mode == ThemeMode.dark);

    notifyListeners();
  }
}
