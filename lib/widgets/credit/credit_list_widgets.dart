import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/constants.dart';

/// Shared pieces of the Leruma credit & debt screens
/// (design_handoff_home_credit, screen 3).
///
/// The supervisor list and the customer list are the same screen at two levels,
/// so they share these widgets rather than each carrying its own copy -- the
/// pair of screens in `credits_screen.dart` had already drifted apart once.

final NumberFormat creditMoney = NumberFormat('#,###');

// ---------------------------------------------------------------------------
// Dark-mode surfaces.
//
// The handoff specifies one light palette, so these resolve each design colour
// against the active theme. MaterialApp switches its brightness from
// ThemeProvider, so Theme.of is enough and these stay usable from plain
// StatelessWidgets.
// ---------------------------------------------------------------------------

bool creditDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Page background (design #F2F5F9).
Color creditPageBg(BuildContext context) =>
    creditDark(context) ? AppColors.darkBackground : const Color(0xFFF2F5F9);

/// Card surface (design white).
Color creditCardBg(BuildContext context) =>
    creditDark(context) ? AppColors.darkCard : Colors.white;

/// Headline / figure text (design #103863).
Color creditInkStrong(BuildContext context) =>
    creditDark(context) ? AppColors.darkText : const Color(0xFF103863);

/// Secondary label text (design #5C6675 / #6B7684).
Color creditInkMuted(BuildContext context) =>
    creditDark(context) ? AppColors.darkTextLight : const Color(0xFF5C6675);

/// Inset blocks inside a card (design #F5F8FC).
Color creditInset(BuildContext context) => creditDark(context)
    ? Colors.white.withValues(alpha: 0.06)
    : const Color(0xFFF5F8FC);

/// Hairlines (design #F1F4F8).
Color creditHairline(BuildContext context) => creditDark(context)
    ? Colors.white.withValues(alpha: 0.10)
    : const Color(0xFFF1F4F8);

/// Progress tracks (design #EEF2F7).
Color creditTrack(BuildContext context) => creditDark(context)
    ? Colors.white.withValues(alpha: 0.12)
    : const Color(0xFFEEF2F7);

/// Field / chip borders (design #E6EBF2).
Color creditBorder(BuildContext context) => creditDark(context)
    ? Colors.white.withValues(alpha: 0.14)
    : const Color(0xFFE6EBF2);

/// Tinted squares: the light tints glow on black, so in dark mode they become
/// a wash of the icon's own colour instead.
Color creditTint(BuildContext context, Color fg, Color lightBg) =>
    creditDark(context) ? fg.withValues(alpha: 0.20) : lightBg;

/// A navy drop shadow on black reads as smudge; the lift comes from the card
/// colour there instead.
List<BoxShadow> creditShadow(BuildContext context) =>
    creditDark(context) ? const [] : creditCardShadow;

const List<BoxShadow> creditCardShadow = [
  BoxShadow(color: Color(0x0D103863), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x12103863), blurRadius: 18, offset: Offset(0, 6)),
];

/// Initials for the row avatar.
///
/// Non-letter tokens are skipped, so "Mija (sembe) Mapinga" gives MM and not
/// "M(" -- bracketed nicknames are common in these customer names.
String creditInitials(String name) {
  final words = name
      .split(RegExp(r'\s+'))
      .map((word) => word.replaceAll(RegExp(r'[^A-Za-z]'), ''))
      .where((word) => word.isNotEmpty)
      .toList();

  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first[0].toUpperCase();
  return (words.first[0] + words.last[0]).toUpperCase();
}

/// 3.2 Totals card.
class CreditTotalsCard extends StatelessWidget {
  final double balance;
  final double credit;
  final double paid;
  final int openAccounts;

  const CreditTotalsCard({
    super.key,
    required this.balance,
    required this.credit,
    required this.paid,
    required this.openAccounts,
  });

  @override
  Widget build(BuildContext context) {
    final collected = credit > 0 ? (paid / credit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: creditCardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: creditShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'OUTSTANDING BALANCE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: creditInkMuted(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: creditTint(context, const Color(0xFFC4820E), const Color(0xFFFDF1DC)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC4820E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$openAccounts open',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: creditDark(context)
                            ? const Color(0xFFF0D9A8)
                            : const Color(0xFF8A5F0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  creditMoney.format(balance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Deliberately NOT red: an outstanding balance is normal
                  // business for a distributor, not an error state.
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.3,
                    color: creditInkStrong(context),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'TSh',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: creditInkMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collected this cycle',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: creditInkMuted(context),
                ),
              ),
              Text(
                '${(collected * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF12833C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: collected.toDouble(),
              minHeight: 9,
              backgroundColor: creditTrack(context),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TotalBlock(
                  label: 'TOTAL CREDIT',
                  value: credit,
                  bg: Color(0xFFF5F8FC),
                  labelColor: Color(0xFF6B7684),
                  valueColor: Color(0xFF103863),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TotalBlock(
                  label: 'TOTAL PAID',
                  value: paid,
                  bg: Color(0xFFEEF9F2),
                  labelColor: Color(0xFF3F7355),
                  valueColor: Color(0xFF12833C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalBlock extends StatelessWidget {
  final String label;
  final double value;
  final Color bg;
  final Color labelColor;
  final Color valueColor;

  const _TotalBlock({
    required this.label,
    required this.value,
    required this.bg,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: creditTint(context, valueColor, bg),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: creditDark(context) ? creditInkMuted(context) : labelColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            creditMoney.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor == const Color(0xFF103863)
                  ? creditInkStrong(context)
                  : valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3.4 Search field.
class CreditSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const CreditSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: creditCardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: creditBorder(context), width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 13),
          const Icon(Icons.search, size: 18, color: Color(0xFF8A94A6)),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: creditInkStrong(context),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A94A6),
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: creditTrack(context),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.close, size: 16, color: creditInkMuted(context)),
              ),
            )
          else
            const SizedBox(width: 13),
        ],
      ),
    );
  }
}

/// 3.4 Filter chips: All · With balance · Settled.
class CreditFilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const CreditFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const Map<String, String> filters = {
    'all': 'All',
    'open': 'With balance',
    'settled': 'Settled',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: filters.entries.map((entry) {
        final active = selected == entry.key;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(entry.key),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? (creditDark(context)
                        ? const Color(0xFF2C6FA8)
                        : const Color(0xFF103863))
                    : creditCardBg(context),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: active ? Colors.transparent : creditBorder(context),
                  width: 1.5,
                ),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : creditInkMuted(context),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 3.5 List header with the sort toggle.
class CreditListHeader extends StatelessWidget {
  final String label;
  final bool sortByBalance;
  final VoidCallback onToggleSort;

  const CreditListHeader({
    super.key,
    required this.label,
    required this.sortByBalance,
    required this.onToggleSort,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: creditInkMuted(context),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onToggleSort,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 13, color: Color(0xFF1668A6)),
              const SizedBox(width: 5),
              Text(
                sortByBalance ? 'Highest balance' : 'Name (A-Z)',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1668A6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 3.5 Row card, used at both supervisor and customer level.
class CreditRowCard extends StatelessWidget {
  final String name;
  final String phone;
  final double credit;
  final double paid;
  final double balance;

  /// "Customers" at supervisor level, "Statement" at customer level.
  final String ctaLabel;
  final VoidCallback onTap;

  /// Position in the list; hidden when null. Same circled-number idea as the
  /// suspended / items / customers lists, in this design system's colors.
  final int? number;

  const CreditRowCard({
    super.key,
    required this.name,
    required this.phone,
    required this.credit,
    required this.paid,
    required this.balance,
    required this.ctaLabel,
    required this.onTap,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    final settled = balance <= 0;
    final collected = credit > 0 ? (paid / credit).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: creditCardBg(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: creditCardBg(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: creditShadow(context),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (number != null) ...[
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D7DC4).withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF1D7DC4).withOpacity(0.5)),
                      ),
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: creditInkStrong(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: settled
                          ? const Color(0xFF12833C)
                          : const Color(0xFF1D7DC4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      creditInitials(name),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: creditInkStrong(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.phone,
                                size: 12, color: creditInkMuted(context)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: creditInkMuted(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        creditMoney.format(balance),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: settled
                              ? const Color(0xFF12833C)
                              : creditInkStrong(context),
                        ),
                      ),
                      Text(
                        'balance',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: creditInkMuted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: collected.toDouble(),
                        minHeight: 7,
                        backgroundColor: creditTrack(context),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF16A34A)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${(collected * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3F7355),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 1, color: creditHairline(context)),
              const SizedBox(height: 11),
              Row(
                children: [
                  Flexible(
                    child: _FooterStat(
                        label: 'Credit',
                        value: credit,
                        color: const Color(0xFF103863)),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: _FooterStat(
                        label: 'Paid',
                        value: paid,
                        color: const Color(0xFF12833C)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: creditTint(
                          context, const Color(0xFF1668A6), const Color(0xFFEAF3FB)),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctaLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: creditDark(context)
                                ? const Color(0xFF6FA8DC)
                                : const Color(0xFF1668A6),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 15,
                            color: creditDark(context)
                                ? const Color(0xFF6FA8DC)
                                : const Color(0xFF1668A6)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _FooterStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          creditMoney.format(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color == const Color(0xFF103863)
                ? creditInkStrong(context)
                : color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: creditInkMuted(context),
          ),
        ),
      ],
    );
  }
}

/// Empty search result (3.5).
class CreditEmptyResult extends StatelessWidget {
  final String message;

  const CreditEmptyResult({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: creditInkMuted(context),
          ),
        ),
      ),
    );
  }
}
