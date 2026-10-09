import 'package:flutter/material.dart' hide Text;

import '../l10n/lang.dart';
import 'tr_text.dart';

/// The one "Log out?" confirmation, shared by the drawer and Settings.
///
/// Returns true when the user confirms. Rounded card with a red icon badge,
/// the question, a one-line consequence, and two full-width buttons: a quiet
/// Cancel and a red Log out. Follows the active theme and language.
Future<bool> showLogoutDialog(BuildContext context, {String? userName}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cancel'.tr,
    barrierColor: const Color(0x99000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, __) =>
        _LogoutDialog(userName: userName),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween<double>(begin: 0.88, end: 1).animate(curved), child: child),
      );
    },
  );
  return result == true;
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog({this.userName});

  final String? userName;

  static const _danger = Color(0xFFD93A3A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF1E252D) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF14213D);
    final muted = dark ? Colors.white70 : const Color(0xFF5A6577);
    final hairline = dark ? Colors.white24 : const Color(0xFFE2E8F0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, 18)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge: soft red halo around a solid red disc.
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _danger.withValues(alpha: dark ? 0.18 : 0.10),
                ),
                alignment: Alignment.center,
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
                        color: _danger.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Log out',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to log out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: ink.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You will need to sign in again to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.35, color: muted),
              ),
              if (userName != null && userName!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: dark ? Colors.white10 : const Color(0xFFF3F6FA),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_rounded, size: 16, color: muted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          userName!,
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
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
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.logout_rounded, size: 19),
                      label: const Text('Log out'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: _danger,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
