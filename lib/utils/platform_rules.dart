import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform rules the App Store forces on us.
///
/// App Review rejected Mopos 1.0.2 (6) under guideline 3.1.1 on 2026-08-05:
///
///   "The app includes an account registration feature for businesses and
///    organizations, which is considered access to external mechanisms for
///    purchases or subscriptions to be used in the app.
///    Next Steps: Remove the account registration features for business and
///    organizations."
///
/// Apple treats signing a business up, and sending them to Pesapal to pay,
/// as buying a digital subscription outside In-App Purchase. Both have to be
/// unreachable in the iOS build. Neither restriction applies to Android or
/// the web build, so this is gated by platform rather than deleted -- the
/// backend endpoints are untouched and Play keeps the full flow.
class PlatformRules {
  const PlatformRules._();

  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Whether a business may create its own account from inside the app.
  static bool get allowsSelfSignup => !_isIOS;

  /// Whether the app may send the user to an external payment page to buy or
  /// renew a subscription.
  static bool get allowsExternalSubscriptionPurchase => !_isIOS;
}
