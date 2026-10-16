import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/lang.dart';
import 'tr_text.dart';

/// The one "Delete?" confirmation, used wherever the app deletes or removes
/// something.
///
/// Returns true when the user confirms, false or null when they cancel or tap
/// outside. A rounded card with a pulsing red trash badge, the question, an
/// optional card naming what is about to go (with a few detail rows), a
/// "cannot be undone" notice, and two full-width buttons: a quiet Cancel and a
/// red Delete. Follows the active theme and language.
///
/// [title] is the heading ("Delete Customer"); [message] the question under
/// it. [itemName] and [details] describe the thing being deleted. Pass
/// [confirmLabel] for "Remove" and similar, [icon] for a different glyph and
/// [warning] (or an empty string to hide it) to change the notice.
Future<bool?> showDeleteDialog(
  BuildContext context, {
  required String title,
  String? message,
  String? itemName,
  Map<String, String> details = const {},
  String confirmLabel = 'Delete',
  String? warning,
  IconData icon = Icons.delete_outline_rounded,
}) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cancel'.tr,
    barrierColor: const Color(0xA6000000),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, _, __) => _DeleteDialog(
      title: title,
      message: message,
      itemName: itemName,
      details: details,
      confirmLabel: confirmLabel,
      warning: warning ?? 'This action cannot be undone.',
      icon: icon,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({
    required this.title,
    required this.message,
    required this.itemName,
    required this.details,
    required this.confirmLabel,
    required this.warning,
    required this.icon,
  });

  final String title;
  final String? message;
  final String? itemName;
  final Map<String, String> details;
  final String confirmLabel;
  final String warning;
  final IconData icon;

  static const _danger = Color(0xFFD93A3A);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF1E252D) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF14213D);
    final muted = dark ? Colors.white70 : const Color(0xFF5A6577);
    final hairline = dark ? Colors.white24 : const Color(0xFFE2E8F0);
    final hasSubject = (itemName != null && itemName!.trim().isNotEmpty) || details.isNotEmpty;

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(color: Color(0x52000000), blurRadius: 44, offset: Offset(0, 20)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Danger band with the pulsing trash badge.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _danger.withValues(alpha: dark ? 0.22 : 0.13),
                          _danger.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: _PulsingBadge(icon: icon, color: _danger),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.2,
                            color: ink,
                          ),
                        ),
                        if (message != null && message!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: ink.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                        if (hasSubject) ...[
                          const SizedBox(height: 16),
                          _SubjectCard(
                            itemName: itemName,
                            details: details,
                            ink: ink,
                            muted: muted,
                            hairline: hairline,
                            dark: dark,
                          ),
                        ],
                        if (warning.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: dark ? 0.16 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 18, color: Color(0xFFD98200)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    warning,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: dark ? const Color(0xFFFFC857) : const Color(0xFF9A5B00),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  foregroundColor: ink,
                                  side: BorderSide(color: hairline, width: 1.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFEF5656), Color(0xFFC62828)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _danger.withValues(alpha: 0.38),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.heavyImpact();
                                    Navigator.of(context).pop(true);
                                  },
                                  icon: Icon(icon, size: 20),
                                  label: Text(confirmLabel),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft red halo around a solid red disc; the halo breathes and the glyph
/// gives a small wobble when the dialog opens.
class _PulsingBadge extends StatefulWidget {
  const _PulsingBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Halo grows and fades once per cycle.
        final ring = Curves.easeOut.transform(t);
        // A quick wobble in the first fifth of each cycle, still afterwards.
        final wobble = t < 0.2 ? (0.5 - (t / 0.2 - 0.5).abs()) * 2 : 0.0;
        return SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 78 + 32 * ring,
                height: 78 + 32 * ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.16 * (1 - ring)),
                ),
              ),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.12),
                ),
              ),
              Transform.rotate(
                angle: wobble * 0.18 * (t < 0.1 ? 1 : -1),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEF5656), Color(0xFFC62828)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 32),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "What is going" card: the item's name and a few label/value rows.
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.itemName,
    required this.details,
    required this.ink,
    required this.muted,
    required this.hairline,
    required this.dark,
  });

  final String? itemName;
  final Map<String, String> details;
  final Color ink;
  final Color muted;
  final Color hairline;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final hasName = itemName != null && itemName!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasName)
            Text(
              itemName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          if (hasName && details.isNotEmpty) const SizedBox(height: 8),
          for (final entry in details.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(fontSize: 13.5, color: muted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
