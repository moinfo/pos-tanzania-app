import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pos_tanzania_mobile/providers/auth_provider.dart';
import 'package:pos_tanzania_mobile/widgets/inactivity_gate.dart';

/// Only the two members the gate reads. Everything else is unreachable.
class _FakeAuth extends ChangeNotifier implements AuthProvider {
  _FakeAuth({this.authenticated = true});

  bool authenticated;
  int logouts = 0;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<void> logout() async {
    logouts++;
    authenticated = false;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final navKey = GlobalKey<NavigatorState>();
  var clock = DateTime(2026, 1, 1, 9);

  /// Moves the gate's clock and the test's timers forward together, one second
  /// at a time -- the gate ticks once a second, as it does on a device.
  Future<void> elapse(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      clock = clock.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<_FakeAuth> pumpGate(WidgetTester tester, {bool authed = true}) async {
    clock = DateTime(2026, 1, 1, 9);
    final auth = _FakeAuth(authenticated: authed);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          navigatorKey: navKey,
          builder: (context, child) => InactivityGate(
            navigatorKey: navKey,
            timeout: const Duration(seconds: 10),
            warning: const Duration(seconds: 4),
            now: () => clock,
            signedOutBuilder: (_) => const Scaffold(body: Text('LOGIN')),
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('HOME'))),
        ),
      ),
    );
    return auth;
  }

  testWidgets('no warning while the person is active', (tester) async {
    final auth = await pumpGate(tester);

    for (var i = 0; i < 4; i++) {
      await elapse(tester, 3);
      await tester.tapAt(const Offset(20, 20)); // activity
    }

    expect(find.text('Are you still there?'), findsNothing);
    expect(auth.logouts, 0);
  });

  testWidgets('warns 4s before the limit, counting down', (tester) async {
    await pumpGate(tester);

    await elapse(tester, 5); // idle 5s < 6s: nothing yet
    expect(find.text('Are you still there?'), findsNothing);

    await elapse(tester, 2); // idle 7s -> 3s left
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Are you still there?'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await elapse(tester, 1);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('"Stay signed in" cancels and restarts the clock', (tester) async {
    final auth = await pumpGate(tester);

    await elapse(tester, 7);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Are you still there?'), findsOneWidget);

    await tester.tap(find.text('Stay signed in'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Are you still there?'), findsNothing);

    // Well past the ORIGINAL deadline, but inside a fresh limit: still in.
    await elapse(tester, 5);
    expect(auth.logouts, 0);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('signs out and lands on login at the limit', (tester) async {
    final auth = await pumpGate(tester);

    await elapse(tester, 11);
    await tester.pumpAndSettle();

    expect(auth.logouts, 1);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Are you still there?'), findsNothing);
  });

  testWidgets('taps on the dimmed screen do not cancel the warning',
      (tester) async {
    final auth = await pumpGate(tester);

    await elapse(tester, 7);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Are you still there?'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5)); // on the barrier, not a button
    await elapse(tester, 4);
    await tester.pumpAndSettle();

    expect(auth.logouts, 1);
  });

  testWidgets('does nothing when nobody is signed in', (tester) async {
    final auth = await pumpGate(tester, authed: false);

    await elapse(tester, 30);

    expect(find.text('Are you still there?'), findsNothing);
    expect(auth.logouts, 0);
  });
}
