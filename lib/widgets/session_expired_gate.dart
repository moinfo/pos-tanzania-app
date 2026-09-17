import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../services/session_guard.dart';

/// Takes the screen when the server stops accepting this session.
///
/// Mounted in MaterialApp.builder, above the Navigator, for the reason the
/// previous arrangement failed: the only thing that watched for a dead session
/// was a widget deep in the tree, so anything pushed on top of it -- a sale, a
/// report, the dashboard in the bug report -- kept the person looking at an
/// error with a Try again button that could never succeed.
///
/// It signs out for real (which unregisters the handset from push, clears
/// permissions, locations and the cart) and sends the person to the login
/// screen with every route behind it removed.
class SessionExpiredGate extends StatefulWidget {
  const SessionExpiredGate({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<SessionExpiredGate> createState() => _SessionExpiredGateState();
}

class _SessionExpiredGateState extends State<SessionExpiredGate> {
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    SessionGuard.expired.addListener(_onExpired);
  }

  @override
  void dispose() {
    SessionGuard.expired.removeListener(_onExpired);
    super.dispose();
  }

  /// Sign out as soon as the session is known to be dead, without waiting for
  /// the person to tap anything: the app is useless in this state and every
  /// background poll is still sending a token the server has refused.
  Future<void> _onExpired() async {
    if (!SessionGuard.expired.value || _signingOut) return;
    _signingOut = true;

    final navigator = widget.navigatorKey.currentState;
    final context = navigator?.context;
    if (context == null) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    // Every route behind it goes: what is underneath belongs to a session that
    // no longer exists.
    navigator!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SessionGuard.expired,
      child: widget.child,
      builder: (context, expired, child) {
        if (!expired) return child!;
        // Held until the sign-out finishes and the login screen is in place,
        // so nothing behind it can be tapped meanwhile.
        return Stack(
          children: [
            ExcludeFocus(child: IgnorePointer(child: child!)),
            const _SessionExpiredScreen(),
          ],
        );
      },
    );
  }
}

class _SessionExpiredScreen extends StatelessWidget {
  const _SessionExpiredScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Muda wa kuingia umeisha',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tafadhali ingia tena / Your session has expired. '
                  'Please sign in again.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
