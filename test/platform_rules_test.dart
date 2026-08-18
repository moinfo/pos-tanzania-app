import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/utils/platform_rules.dart';

// Guards the App Store 3.1.1 remedy. The rejection was specifically that a
// business could register, and by extension pay, from inside the iOS app.
// These run on the host VM, so they assert the non-iOS side stays open --
// the iOS side is enforced by the same single flag both getters read.
void main() {
  group('PlatformRules', () {
    test('self signup is allowed off iOS', () {
      expect(PlatformRules.allowsSelfSignup, isTrue);
    });

    test('external subscription purchase is allowed off iOS', () {
      expect(PlatformRules.allowsExternalSubscriptionPurchase, isTrue);
    });

    test('both rules move together', () {
      // One flag drives both, so a future change cannot silently re-open
      // signup while leaving payment closed, or the reverse.
      expect(PlatformRules.allowsSelfSignup,
          PlatformRules.allowsExternalSubscriptionPurchase);
    });
  });
}
