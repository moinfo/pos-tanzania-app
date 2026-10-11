import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'brand_backdrop.dart';

/// Colours for a dialog header: the client's brand gradient where it has one,
/// otherwise [fallback] deepened into its own shade.
List<Color> _headerColors(Color fallback) =>
    BrandBackdrop.gradientFor(ApiService.currentClient) ??
    [fallback, Color.lerp(fallback, Colors.black, 0.25)!];

/// Asks the person to confirm signing out. Resolves to true only on "Log out".
///
/// One dialog for every place that can sign out (the drawer header and
/// Settings), so the confirmation cannot drift between them.
Future<bool> showLogoutConfirmation(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => const _LogoutConfirmDialog(),
    transitionBuilder: dialogTransition,
  );
  return result == true;
}

/// Fade + spring-scale used by both dialogs.
Widget dialogTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
      child: child,
    ),
  );
}

/// A card with a coloured header, a round badge that overlaps it, and a body.
class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.colors,
    required this.badge,
    required this.child,
  });

  final List<Color> colors;
  final Widget badge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: Container(
                  height: 132,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Soft bubbles, so the header is not a flat slab.
                      Positioned(
                        left: -26,
                        top: -30,
                        child: _bubble(110, 0.10),
                      ),
                      Positioned(
                        right: -20,
                        bottom: -38,
                        child: _bubble(130, 0.12),
                      ),
                      Positioned(
                        right: 70,
                        top: 18,
                        child: _bubble(26, 0.14),
                      ),
                      badge,
                    ],
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }

  static Widget _bubble(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

/// A tall, rounded dialog button. [filled] draws the gradient; otherwise an
/// outline.
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.colors,
    this.dark = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  /// Null for the outlined button.
  final List<Color>? colors;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final filled = colors != null;
    final fg = filled
        ? Colors.white
        : (dark ? AppColors.darkText : AppColors.text);

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: colors!,
                )
              : null,
          border: filled
              ? null
              : Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xFFD5DBE5),
                  width: 1.4,
                ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: colors!.last.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

/// Who is about to be signed out, as a small pill.
class _UserPill extends StatelessWidget {
  const _UserPill({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final name = user?.displayName ?? '';
    if (name.isEmpty) return const SizedBox.shrink();

    final brand = _headerColors(AppColors.primary);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: dark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFF1F5FA),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: brand,
              ),
            ),
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: dark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutConfirmDialog extends StatelessWidget {
  const _LogoutConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.darkTextLight : AppColors.textLight;
    const danger = [Color(0xFFEF4444), Color(0xFFB91C1C)];

    return _DialogShell(
      colors: _headerColors(AppColors.primary),
      badge: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.logout_rounded,
            size: 38, color: Color(0xFFEF4444)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log out?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: dark ? AppColors.darkText : AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            _UserPill(dark: dark),
            const SizedBox(height: 14),
            Text(
              'You will need to sign in again to keep working. '
              'Anything you have not saved will be lost.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: muted),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Stay signed in',
                    dark: dark,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DialogButton(
                    label: 'Log out',
                    icon: Icons.logout_rounded,
                    colors: danger,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The warning shown shortly before an inactive session is signed out.
///
/// It does not decide anything itself: [seconds] is driven by the gate's
/// ticker, and the two callbacks hand the choice back to it.
class InactivityCountdownDialog extends StatelessWidget {
  const InactivityCountdownDialog({
    super.key,
    required this.seconds,
    required this.total,
    required this.onStay,
    required this.onLogout,
  });

  final ValueListenable<int> seconds;
  final int total;
  final VoidCallback onStay;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.darkTextLight : AppColors.textLight;
    const amber = [Color(0xFFF59E0B), Color(0xFFD97706)];

    return PopScope(
      canPop: false,
      child: _DialogShell(
        colors: amber,
        badge: ValueListenableBuilder<int>(
          valueListenable: seconds,
          builder: (context, left, _) => SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                SizedBox(
                  width: 92,
                  height: 92,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (left / total).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.35),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                Text(
                  '$left',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you still there?',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: dark ? AppColors.darkText : AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<int>(
                valueListenable: seconds,
                builder: (context, left, _) => Text(
                  'For your security you will be signed out in '
                  '$left ${left == 1 ? 'second' : 'seconds'} '
                  'because the app has been idle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.45, color: muted),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'Log out now',
                      dark: dark,
                      onTap: onLogout,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: 'Stay signed in',
                      icon: Icons.check_circle_outline_rounded,
                      colors: _headerColors(AppColors.primary),
                      onTap: onStay,
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
