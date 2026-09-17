import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/services/api_service.dart';
import 'package:pos_tanzania_mobile/services/screen_prefetch.dart';

/// The background warm-up walks 40+ list endpoints on sign-in and on resume.
/// On a weak link those queued in front of whatever the seller was waiting on,
/// and that screen then timed out -- the warm-up causing the outage it exists
/// to soften. These pin the parts of that arrangement a refactor could quietly
/// drop.
void main() {
  test('nothing is in flight before a request starts', () {
    expect(ApiService.foregroundBusy, isFalse);
  });

  test('the prefetch pace is slow enough to leave the link usable', () {
    // A hard floor between calls, so a burst cannot monopolise a 2G link end
    // to end even when the foreground is idle.
    expect(ScreenPrefetch.pacing.inMilliseconds, greaterThanOrEqualTo(100));
    // ...and a cap, so a screen that polls forever cannot stall the warm-up
    // forever either.
    expect(ScreenPrefetch.foregroundWaitCap.inSeconds, lessThanOrEqualTo(10));
    expect(ScreenPrefetch.foregroundWaitCap, greaterThan(ScreenPrefetch.pacing));
  });
}
