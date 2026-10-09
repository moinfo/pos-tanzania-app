import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../screens/login_screen.dart';
import '../widgets/tr_text.dart';

/// Signs the user out after a period with no touches, warning first.
///
/// After [idleLimit] without a touch the person has [warning] seconds of
/// visible countdown, during which "Stay signed in" keeps the session. If the
/// countdown reaches zero (or "Log out now" is pressed) the session is closed
/// exactly as the drawer's Log out does, and every route is replaced by the
/// login screen.
///
/// Mounted in MaterialApp.builder above the Navigator so it sees every touch
/// on every screen and can show its dialog over whatever is open.
///
/// Time-based on purpose: a once-a-second tick compares against the last touch
/// instead of counting down a timer. That keeps it correct when the phone
/// sleeps or the app sits in the background -- on return the very next tick
/// finds the idle time already past the limit and signs out.
class InactivityGate extends StatefulWidget {
  const InactivityGate({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// 5 minutes. `--dart-define=IDLE_TIMEOUT_SECONDS=60` shortens it for testing.
  static const int idleSeconds =
      int.fromEnvironment('IDLE_TIMEOUT_SECONDS', defaultValue: 300);

  /// The countdown the user sees: 30 seconds (never more than half the limit).
  static const int warningSeconds = idleSeconds >= 60 ? 30 : idleSeconds ~/ 2;

  @override
  State<InactivityGate> createState() => _InactivityGateState();
}

class _InactivityGateState extends State<InactivityGate> {
  Timer? _ticker;
  late AuthProvider _auth;
  DateTime _lastTouch = DateTime.now();
  bool _warningShown = false;
  bool _signingOut = false;
  final ValueNotifier<int> _secondsLeft =
      ValueNotifier<int>(InactivityGate.warningSeconds);

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _ticker?.cancel();
    _secondsLeft.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated) {
      if (_ticker == null) {
        _lastTouch = DateTime.now();
        _signingOut = false;
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    } else {
      _ticker?.cancel();
      _ticker = null;
      _closeWarning();
    }
  }

  /// A touch anywhere. Ignored while the countdown is up: the only way to keep
  /// the session then is the button, so a stray tap cannot dismiss the warning.
  void _touched() {
    if (_warningShown) return;
    _lastTouch = DateTime.now();
  }

  void _tick() {
    if (!mounted || !_auth.isAuthenticated || _signingOut) return;

    final idle = DateTime.now().difference(_lastTouch).inSeconds;
    final left = InactivityGate.idleSeconds - idle;

    if (left <= 0) {
      _signOut();
    } else if (left <= InactivityGate.warningSeconds) {
      _secondsLeft.value = left;
      if (!_warningShown) _showWarning();
    }
  }

  void _showWarning() {
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null) return;
    _warningShown = true;

    showGeneralDialog<void>(
      context: navContext,
      barrierDismissible: false,
      barrierLabel: 'Stay signed in'.tr,
      barrierColor: const Color(0xB3000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => PopScope(
        canPop: false,
        child: _InactivityDialog(
          secondsLeft: _secondsLeft,
          total: InactivityGate.warningSeconds,
          onStay: _stay,
          onLogout: _signOut,
        ),
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
    ).then((_) => _warningShown = false);
  }

  void _closeWarning() {
    if (!_warningShown) return;
    widget.navigatorKey.currentState?.pop();
    _warningShown = false;
  }

  void _stay() {
    _closeWarning();
    _lastTouch = DateTime.now();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    _closeWarning();

    await _auth.logout();
    if (!mounted) return;

    widget.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touched(),
      onPointerMove: (_) => _touched(),
      onPointerSignal: (_) => _touched(),
      child: widget.child,
    );
  }
}

class _InactivityDialog extends StatelessWidget {
  const _InactivityDialog({
    required this.secondsLeft,
    required this.total,
    required this.onStay,
    required this.onLogout,
  });

  final ValueNotifier<int> secondsLeft;
  final int total;
  final VoidCallback onStay;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF1E252D) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xFF14213D);
    final muted = dark ? Colors.white70 : const Color(0xFF5A6577);
    final brand = AppColors.brandPrimary;
    const warn = Color(0xFFE08A00);

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
              ValueListenableBuilder<int>(
                valueListenable: secondsLeft,
                builder: (context, left, _) {
                  // Calm amber, then red for the last ten seconds.
                  final color = left <= 10 ? const Color(0xFFD93A3A) : warn;
                  return SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: (left / total).clamp(0.0, 1.0),
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            backgroundColor: color.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$left',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'seconds',
                              style: TextStyle(fontSize: 12.5, color: muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              Text(
                'Are you still there?',
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
                'For your security you will be logged out automatically because of inactivity.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.4, color: muted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onStay,
                  icon: const Icon(Icons.verified_user_rounded, size: 20),
                  label: Text('Stay signed in'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onLogout,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: const Color(0xFFD93A3A),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text('Log out now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
