import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'portal_locale.dart';

/// SW/EN toggle for a portal screen -- shows the language you'd switch TO
/// (tapping while in English shows "SW", and vice versa), same convention
/// as a light/dark mode toggle showing the mode you'd switch to. Defaults
/// to white text for an AppBar on a dark background; pass [dark] for
/// placement directly on a light background (no AppBar), e.g. the
/// Dashboard/Account tabs.
class PortalLanguageSwitch extends StatelessWidget {
  final bool dark;

  const PortalLanguageSwitch({super.key}) : dark = false;

  const PortalLanguageSwitch.themed({super.key, required this.dark});

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.primary : Colors.white;
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, lang, _) {
        final switchTo = lang == 'en' ? 'SW' : 'EN';
        return TextButton.icon(
          onPressed: PortalLocale.instance.toggle,
          style: TextButton.styleFrom(foregroundColor: color),
          icon: Icon(Icons.translate, size: 18, color: color),
          label: Text(switchTo,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}
