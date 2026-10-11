import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import 'session_dialogs.dart';

/// Signs the person out after a stretch of no activity.
///
/// After [timeout] with no touch or key press the session ends. [warning]
/// before that, a countdown dialog appears; tapping "Stay signed in" restarts
/// the clock, anything else lets it run out.
///
/// Mounted in MaterialApp.builder with the other gates, so it covers every
/// screen and every pushed route. It counts the wall clock rather than a
/// timer's ticks, so time spent with the app in the background counts too: a
/// phone left on a counter overnight must not still be signed in.
class InactivityGate extends StatefulWidget {
  const InactivityGate({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.timeout = const Duration(minutes: 5),
    this.warning = const Duration(seconds: 30),
    this.signedOutBuilder,
    this.now = DateTime.now,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final Duration timeout;
  final Duration warning;

  /// The wall clock. Injectable because tests fake the passage of time and
  /// `DateTime.now` is not part of what they fake.
  final DateTime Function() now;

  /// Where the person lands after being signed out. Defaults to the login
  /// screen; exists so the gate can be tested without that screen's services.
  final WidgetBuilder? signedOutBuilder;

  @override
  State<InactivityGate> createState() => _InactivityGateState();
}

class _InactivityGateState extends State<InactivityGate> {
  late DateTime _lastActivity;
  Timer? _ticker;

  /// Seconds left, as the dialog shows it.
  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(0);

  /// The warning's route, so it can be removed without guessing what is on top.
  Route<void>? _warningRoute;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _lastActivity = widget.now();
    HardwareKeyboard.instance.addHandler(_onKey);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _secondsLeft.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    _noteActivity();
    return false; // never swallow the key
  }

  /// Any touch counts, except while the warning is up: from then on only the
  /// dialog's own buttons decide, otherwise a stray tap on the dimmed screen
  /// behind it would quietly cancel a sign-out the person was told about.
  void _noteActivity() {
    if (_warningRoute != null || _signingOut) return;
    _lastActivity = widget.now();
  }

  void _tick() {
    if (!mounted || _signingOut) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      // Nobody is signed in: nothing to time out, and no warning to keep.
      _closeWarning();
      _lastActivity = widget.now();
      return;
    }

    final idle = widget.now().difference(_lastActivity);
    final left = widget.timeout - idle;

    if (left <= Duration.zero) {
      _expire();
    } else if (left <= widget.warning) {
      _secondsLeft.value = (left.inMilliseconds / 1000).ceil();
      _showWarning();
    }
  }

  void _showWarning() {
    if (_warningRoute != null) return;
    final navigator = widget.navigatorKey.currentState;
    final overlayContext = navigator?.overlay?.context;
    if (navigator == null || overlayContext == null) return;

    final route = RawDialogRoute<void>(
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierLabel: 'Inactivity warning',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => InactivityCountdownDialog(
        seconds: _secondsLeft,
        total: widget.warning.inSeconds,
        onStay: _stay,
        onLogout: _expire,
      ),
      transitionBuilder: dialogTransition,
    );
    _warningRoute = route;
    navigator.push(route).whenComplete(() {
      // Closed by something other than us (a pop): forget the stale route.
      if (identical(_warningRoute, route)) _warningRoute = null;
    });
  }

  void _closeWarning() {
    final route = _warningRoute;
    _warningRoute = null;
    if (route != null && route.isActive) {
      widget.navigatorKey.currentState?.removeRoute(route);
    }
  }

  void _stay() {
    _closeWarning();
    _lastActivity = widget.now();
  }

  Future<void> _expire() async {
    if (_signingOut) return;
    _signingOut = true;

    _closeWarning();
    final navigator = widget.navigatorKey.currentState;
    final navContext = navigator?.context;

    try {
      if (navContext == null || !navContext.mounted) return;
      await navContext.read<AuthProvider>().logout();
      if (!mounted || navigator == null) return;

      // Every route behind goes: it belongs to a session that no longer exists.
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: widget.signedOutBuilder ?? (_) => const LoginScreen(),
        ),
        (route) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = widget.navigatorKey.currentContext;
        if (ctx == null) return;
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'You were signed out after '
              '${widget.timeout.inMinutes} minutes of inactivity.',
            ),
          ),
        );
      });
    } finally {
      _signingOut = false;
      _lastActivity = widget.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _noteActivity(),
      onPointerMove: (_) => _noteActivity(),
      onPointerSignal: (_) => _noteActivity(),
      child: widget.child,
    );
  }
}
