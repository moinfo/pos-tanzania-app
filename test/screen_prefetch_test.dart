import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/services/screen_prefetch.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The scheduling half of the background warm.
///
/// The pacing is the part that costs the user money -- every run is data off a
/// bundle -- and the part that decides whether the phone has anything on it
/// when the signal goes. Both directions are wrong in their own way: too eager
/// burns the bundle, too lazy leaves the seller with a blank screen.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScreenPrefetch.resetForTest();
  });

  test('a device that has never warmed is due immediately', () async {
    expect(await ScreenPrefetch.isDue(), isTrue);
    expect(await ScreenPrefetch.lastRun(), isNull);
  });

  test('a warm that just ran is not due again', () async {
    SharedPreferences.setMockInitialValues({
      'screen_prefetch_last_run': DateTime.now().toIso8601String(),
    });
    expect(await ScreenPrefetch.isDue(), isFalse);
  });

  test('a warm older than the interval is due again', () async {
    final stale = DateTime.now().subtract(ScreenPrefetch.interval * 2);
    SharedPreferences.setMockInitialValues({
      'screen_prefetch_last_run': stale.toIso8601String(),
    });
    expect(await ScreenPrefetch.isDue(), isTrue);
  });

  test('an unreadable stamp is treated as never warmed, not as fresh', () async {
    SharedPreferences.setMockInitialValues({
      'screen_prefetch_last_run': 'not a date',
    });
    // Reading it back as "fresh" would silently disable the warm forever on
    // that device, and nothing on screen would say so.
    expect(await ScreenPrefetch.isDue(), isTrue);
  });

  group('what a run reports back', () {
    test('a skipped run is distinguishable from one that did nothing', () {
      final skipped = PrefetchOutcome.skipped('offline');
      final ran = PrefetchOutcome(loaded: 0, failed: 4, ranAt: DateTime.now());

      // Both loaded nothing, but only one of them tried. The Settings sheet
      // has to tell "we did not look" apart from "we looked and it failed".
      expect(skipped.didRun, isFalse);
      expect(ran.didRun, isTrue);
      expect(skipped.skippedBecause, 'offline');
    });
  });
}
