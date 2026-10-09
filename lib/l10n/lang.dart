import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sw_strings.dart';

/// English / Kiswahili for the whole app.
///
/// Source strings in the code stay English. [tr] turns one into the active
/// language at display time, so a screen needs no per-string plumbing: the
/// translating [Text] widget (widgets/tr_text.dart) and the `.tr` extension
/// both go through here.
///
/// A string with values in it ("Total: 1,200") cannot be a dictionary key, so
/// the dictionary also holds templates written with `{}` placeholders
/// ("Total: {}"). The display string is matched against them and the captured
/// values are put back into the Kiswahili template (`{}` in order, or `{2}` to
/// reorder).
class Lang extends ChangeNotifier {
  Lang._();
  static final Lang instance = Lang._();

  static const String english = 'en';
  static const String swahili = 'sw';
  static const List<Locale> supportedLocales = [Locale('en'), Locale('sw')];

  static const _prefsKey = 'app_language';

  String _code = english;

  static String get code => instance._code;
  static bool get isSwahili => instance._code == swahili;
  static Locale get locale => Locale(instance._code);

  /// Read the saved language before the first frame so the app does not paint
  /// in English and then flip.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == english || saved == swahili) instance._code = saved!;
    } catch (_) {
      // Default (English) is a fine fallback.
    }
  }

  static Future<void> set(String code) async {
    if (code != english && code != swahili) return;
    if (code == instance._code) return;
    instance._code = code;
    _cache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
    instance.notifyListeners();
    // Some strings are translated where a screen builds them (hints, labels,
    // tooltips), not inside a Text. Rebuild every element so those pick the new
    // language up too; state is untouched, exactly as a hot reload.
    try {
      if (WidgetsBinding.instance.rootElement != null) {
        await WidgetsBinding.instance.reassembleApplication();
      }
    } catch (_) {}
  }

  static Future<void> toggle() => set(isSwahili ? english : swahili);

  // ---------------------------------------------------------------------------

  static final Map<String, String> _cache = {};
  static Map<String, String>? _lower;
  static List<_Template>? _leading;
  static Map<String, List<_Template>>? _byPrefix;

  // A handful of strings were written in Kiswahili in the code; show them in
  // English when English is chosen.
  static const Map<String, String> _swToEn = {
    'Karibu tena': 'Welcome back',
    'Asante!': 'Thank you!',
    'Muda wa kuingia umeisha': 'Session expired',
  };

  static String tr(String s) {
    if (instance._code == english) return _swToEn[s] ?? s;
    if (s.isEmpty) return s;
    final hit = _cache[s];
    if (hit != null) return hit;
    final out = _lookup(s);
    // Bounded: dynamic strings (names, amounts) would otherwise grow it forever.
    if (_cache.length > 4000) _cache.clear();
    _cache[s] = out;
    return out;
  }

  static String _lookup(String s) {
    final exact = kSwExact[s];
    if (exact != null) return exact;

    // Whitespace around the text is layout, not content.
    final trimmed = s.trim();
    if (trimmed != s && trimmed.isNotEmpty) {
      final core = _lookup(trimmed);
      if (core != trimmed) {
        final start = s.indexOf(trimmed);
        return s.substring(0, start) + core + s.substring(start + trimmed.length);
      }
    }

    // Code often upper-cases a label for display ("SAVE").
    _lower ??= {for (final e in kSwExact.entries) e.key.toLowerCase(): e.value};
    final lower = _lower![s.toLowerCase()];
    if (lower != null) {
      if (s == s.toUpperCase() && s != s.toLowerCase()) return lower.toUpperCase();
      return lower;
    }

    return _matchTemplate(s) ?? s;
  }

  static String? _matchTemplate(String s) {
    if (_byPrefix == null) _buildTemplates();
    final candidates = <_Template>[
      if (s.length >= 3) ...?_byPrefix![s.substring(0, 3)],
      ..._leading!,
    ]..sort((a, b) => b.specificity.compareTo(a.specificity));
    // Most literal text first: "Page {} of {}" must win over "Page {}".
    for (final t in candidates) {
      final m = t.regex.firstMatch(s);
      if (m == null) continue;
      final values = [for (var i = 1; i <= m.groupCount; i++) m.group(i) ?? ''];
      // Values that are themselves translatable words ("Cash", "Pending").
      final translated = [for (final v in values) kSwExact[v] ?? v];
      return t.fill(translated);
    }
    return null;
  }

  static void _buildTemplates() {
    _byPrefix = {};
    _leading = [];
    for (final e in kSwTemplates.entries) {
      final t = _Template(e.key, e.value);
      final prefix = t.literalPrefix;
      if (prefix.length >= 3) {
        (_byPrefix![prefix.substring(0, 3)] ??= []).add(t);
      } else {
        _leading!.add(t);
      }
    }
  }
}

class _Template {
  _Template(String source, this._target) {
    final parts = source.split('{}');
    literalPrefix = parts.first;
    specificity = parts.fold<int>(0, (n, p) => n + p.length);
    final b = StringBuffer('^');
    for (var i = 0; i < parts.length; i++) {
      b.write(RegExp.escape(parts[i]));
      if (i < parts.length - 1) b.write('(.*?)');
    }
    b.write(r'$');
    regex = RegExp(b.toString(), dotAll: true);
  }

  late final RegExp regex;
  late final String literalPrefix;
  late final int specificity;
  final String _target;

  static final _slot = RegExp(r'\{(\d*)\}');

  String fill(List<String> values) {
    var next = 0;
    return _target.replaceAllMapped(_slot, (m) {
      final n = m.group(1)!;
      final idx = n.isEmpty ? next++ : int.parse(n) - 1;
      return idx >= 0 && idx < values.length ? values[idx] : '';
    });
  }
}

extension LangString on String {
  /// This (English) string in the active language.
  String get tr => Lang.tr(this);
}
