import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' hide Text;

import '../l10n/lang.dart';

/// Drop-in replacement for Flutter's [m.Text] that shows its string in the
/// active language (English / Kiswahili).
///
/// Screens import this instead of the framework's Text:
///
///     import 'package:flutter/material.dart' hide Text;
///     import '../widgets/tr_text.dart';
///
/// Every `Text('Save')`, `const Text('Save')` and `Text(label)` then translates
/// at build time, with no other change to the call site.
class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  static InlineSpan _span(InlineSpan s) {
    if (s is TextSpan) {
      return TextSpan(
        text: s.text == null ? null : Lang.tr(s.text!),
        children: s.children?.map(_span).toList(),
        style: s.style,
        recognizer: s.recognizer,
        mouseCursor: s.mouseCursor,
        onEnter: s.onEnter,
        onExit: s.onExit,
        semanticsLabel: s.semanticsLabel,
        locale: s.locale,
        spellOut: s.spellOut,
      );
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (textSpan != null) {
      return m.Text.rich(
        _span(textSpan!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return m.Text(
      Lang.tr(data!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
