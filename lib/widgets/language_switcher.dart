import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as fw show Text;

import '../l10n/lang.dart';
import 'tr_text.dart';

/// Compact "EN | SW" pill. One tap flips the whole app between English and
/// Kiswahili; the choice is remembered (see [Lang]).
///
/// Colours are passed in because it sits on differently themed surfaces: the
/// login top bar and the landing app bar. The "EN" / "SW" labels use the
/// framework's Text on purpose -- they are names and must never be translated.
class LanguageChip extends StatelessWidget {
  const LanguageChip({
    super.key,
    required this.surface,
    required this.border,
    required this.ink,
    required this.accent,
  });

  final Color surface;
  final Color border;
  final Color ink;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Lang.instance,
      builder: (context, _) {
        Widget half(String label, bool active) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: active ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: fw.Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: active ? Colors.white : ink,
                ),
              ),
            );

        return Tooltip(
          message: Lang.isSwahili ? 'Badilisha lugha' : 'Change language',
          child: Material(
            color: surface,
            shape: StadiumBorder(side: BorderSide(color: border)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: Lang.toggle,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    half('EN', !Lang.isSwahili),
                    half('SW', Lang.isSwahili),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Settings rows: pick English or Kiswahili.
class LanguageSelectorTile extends StatelessWidget {
  const LanguageSelectorTile({
    super.key,
    required this.titleColor,
    required this.subtitleColor,
    required this.accent,
  });

  final Color titleColor;
  final Color subtitleColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Lang.instance,
      builder: (context, _) {
        Widget option(String code, String name) {
          final selected = Lang.code == code;
          return ListTile(
            onTap: () => Lang.set(code),
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? accent : subtitleColor,
            ),
            // Language names are shown in their own language, untranslated.
            title: fw.Text(
              name,
              style: TextStyle(
                color: titleColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }

        return Column(
          children: [
            ListTile(
              leading: Icon(Icons.language, color: accent, size: 28),
              title: Text(
                'Language',
                style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Choose the language of the app',
                style: TextStyle(color: subtitleColor, fontSize: 13),
              ),
            ),
            option(Lang.english, 'English'),
            option(Lang.swahili, 'Kiswahili'),
          ],
        );
      },
    );
  }
}
