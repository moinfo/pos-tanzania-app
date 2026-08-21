import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/services/app_badge_service.dart';

/// The launcher badge has no in-app surface to look at, so the only way to
/// assert on it is at the platform channel: what the app ASKS the launcher for.
///
/// The cases that matter are the ones a simulator cannot show. Every iPhone
/// supports badges, so "a launcher that says no" and "a launcher that throws"
/// -- the two states that would otherwise crash or spam the log on a real
/// Android handset -- can only be exercised here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const badgeChannel = MethodChannel('app_badge_plus');
  const localChannel = MethodChannel('dexterous.com/flutter/local_notifications');

  late List<MethodCall> calls;
  late bool supported;
  late bool throwOnUpdate;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(badgeChannel, (call) async {
      calls.add(call);
      if (call.method == 'isSupported') return supported;
      if (call.method == 'updateBadge' && throwOnUpdate) {
        throw PlatformException(code: 'BADGE', message: 'launcher refused');
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localChannel, (call) async {
      calls.add(call);
      return null;
    });
  }

  /// setCount is deliberately fire-and-forget, so give its queue a turn.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    // Outside a real app nothing registers a local-notifications platform, and
    // the plugin's instance field is `late` -- so cancelAll() would throw a
    // LateInitializationError that says nothing about badges.
    IOSFlutterLocalNotificationsPlugin.registerWith();

    calls = <MethodCall>[];
    supported = true;
    throwOnUpdate = false;
    AppBadgeService.instance.resetForTest();
    install();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(badgeChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localChannel, null);
  });

  List<MethodCall> updates() =>
      calls.where((c) => c.method == 'updateBadge').toList();

  test('the count reaches the launcher', () async {
    AppBadgeService.instance.setCount(4);
    await settle();

    expect(updates(), hasLength(1));
    expect(updates().single.arguments, {'count': 4});
  });

  test('the same count twice costs one platform call, not two', () async {
    AppBadgeService.instance.setCount(4);
    await settle();
    AppBadgeService.instance.setCount(4);
    await settle();

    // NotificationProvider notifies for reasons unrelated to the count -- a
    // loading flag, a feed merge -- and each of those would otherwise be a
    // channel round trip plus a vendor broadcast on Samsung and Sony.
    expect(updates(), hasLength(1));
  });

  test('the badge goes DOWN as well as up, and zero clears the tray with it',
      () async {
    AppBadgeService.instance.setCount(5);
    await settle();
    AppBadgeService.instance.setCount(2);
    await settle();
    AppBadgeService.instance.clear();
    await settle();

    expect(updates().map((c) => (c.arguments as Map)['count']), [5, 2, 0]);

    // On the stock Android launcher the icon mark is a dot derived from ACTIVE
    // notifications, not from any number we set, so a cleared count with a
    // populated tray still shows a dot over an empty inbox.
    expect(calls.where((c) => c.method == 'cancelAll'), hasLength(1));
  });

  test('a launcher without badges is asked once and then left alone', () async {
    supported = false;

    AppBadgeService.instance.setCount(1);
    await settle();
    AppBadgeService.instance.setCount(2);
    await settle();
    AppBadgeService.instance.setCount(3);
    await settle();

    // Asked once, cached forever: this is a normal handset, not a fault, and
    // it must not produce a probe or a log line on every poll.
    expect(calls.where((c) => c.method == 'isSupported'), hasLength(1));
    expect(updates(), isEmpty);
  });

  test('support is probed BEFORE the first count, never after', () async {
    AppBadgeService.instance.setCount(7);
    await settle();

    // The Android side of isSupported() probes the launcher by writing a ZERO
    // badge. Asking after setting a count would wipe the count just set, so
    // the order here is load-bearing rather than incidental.
    expect(calls.first.method, 'isSupported');
    expect(calls[1].method, 'updateBadge');
  });

  test('a launcher that throws does not take the caller down with it',
      () async {
    throwOnUpdate = true;

    // No await, no try: this is exactly how NotificationProvider calls it, and
    // an unhandled rejection here would surface as an uncaught async error.
    AppBadgeService.instance.setCount(3);
    await settle();
    await settle();

    expect(updates(), hasLength(1));

    // And the next count still gets through -- one bad vendor broadcast must
    // not disable badging for the rest of the session.
    throwOnUpdate = false;
    AppBadgeService.instance.setCount(4);
    await settle();

    expect(updates(), hasLength(2));
  });

  test('a negative count is floored at zero rather than sent as-is', () async {
    AppBadgeService.instance.setCount(-1);
    await settle();

    expect(updates().single.arguments, {'count': 0});
  });
}
