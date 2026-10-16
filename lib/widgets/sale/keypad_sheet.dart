import 'package:flutter/material.dart' hide Text;

import '../../utils/sale_design.dart';
import '../../widgets/tr_text.dart';

/// Shared shell for the sale screen's bottom sheets.
///
/// The quantity, discount and payment sheets are the same object: a grabber, a
/// header whose right side is the live value, an optional preset row, a 3x4
/// numeric keypad and a footer. Only the header text, presets and footer differ,
/// so they are parameters rather than three near-identical widgets.
class KeypadSheet extends StatelessWidget {
  /// Small uppercase label, e.g. `QUANTITY`.
  final String label;

  /// Second line under [label] -- item name, subtotal, amount due.
  final String subtitle;

  /// Large live value on the right of the header.
  final String value;

  /// Font size of [value]; the handoff uses 34 for quantity and 32 elsewhere.
  final double valueSize;

  /// Dims the figure while it is still the value the sheet opened with, so it
  /// reads as a placeholder that the next keypress will replace.
  final bool valueMuted;

  /// Optional row above the keypad (presets, method chips, mode toggle).
  final List<Widget> aboveKeypad;

  /// Height of each keypad key -- 52 for quantity, 50 for discount/payment.
  final double keyHeight;

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Footer row, typically the confirm button.
  final Widget footer;

  const KeypadSheet({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onDigit,
    required this.onBackspace,
    required this.footer,
    this.aboveKeypad = const [],
    this.valueSize = 32,
    this.valueMuted = false,
    this.keyHeight = 50,
  });

  @override
  Widget build(BuildContext context) {
    final sale = SaleTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: sale.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: sale.sheetShadow,
      ),
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        // Clear the keyboard/gesture inset without leaving a gap when there is none
        bottom: 30 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: sale.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: sale.textFaint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: sale.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: valueMuted
                      ? sale.brand.withValues(alpha: 0.45)
                      : sale.brand,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...aboveKeypad,
          _buildKeypad(context),
          const SizedBox(height: 12),
          footer,
        ],
      ),
    );
  }

  Widget _buildKeypad(BuildContext context) {
    final sale = SaleTheme.of(context);
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['00', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _buildKey(context, row[i])),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey(BuildContext context, String key) {
    final sale = SaleTheme.of(context);
    final isBackspace = key == '⌫';

    return SizedBox(
      height: keyHeight,
      child: Material(
        color: sale.pageBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          highlightColor: sale.neutralFillPressed,
          onTap: isBackspace ? onBackspace : () => onDigit(key),
          child: Center(
            child: isBackspace
                ? Icon(Icons.backspace_outlined,
                    size: 21, color: sale.textSecondary)
                : Text(
                    key,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: sale.textPrimary,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Pill button used for the preset rows (`1 5 10 25 50`, `500 1,000 …`).
class SalePresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double height;

  const SalePresetChip({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    final sale = SaleTheme.of(context);
    return SizedBox(
      height: height,
      child: Material(
        color: sale.blueTint2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          highlightColor: sale.blueTintPressed,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: sale.brand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable chip used for the discount mode toggle and payment methods.
class SaleChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  const SaleChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final sale = SaleTheme.of(context);
    return SizedBox(
      height: height,
      child: Material(
        color: selected ? sale.blueTint1 : sale.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? sale.brand : sale.border,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? sale.brand : sale.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width primary button used at the bottom of each sheet.
class SaleSheetButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color pressedColor;
  final List<BoxShadow> shadow;
  final double height;
  final VoidCallback? onTap;

  const SaleSheetButton({
    super.key,
    required this.label,
    required this.color,
    required this.pressedColor,
    this.icon,
    this.shadow = const [],
    this.height = 52,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sale = SaleTheme.of(context);
    final enabled = onTap != null;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled ? shadow : const [],
      ),
      child: Material(
        color: enabled ? color : sale.iconFaint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          highlightColor: pressedColor,
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19, color: Colors.white),
                  const SizedBox(width: 9),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
