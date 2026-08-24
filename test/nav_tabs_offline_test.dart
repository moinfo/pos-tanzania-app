import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The tabs in the bottom bar must open away from signal.
///
/// A bottom-nav tab is not a page someone chose to visit — it is one of the
/// five things always on screen. When its loader is not cached the tab does not
/// degrade, it dies: the seller taps Credits on a route and gets "No internet
/// connection", with no way forward. That is the defect this pins down, found
/// on a device after vc41 shipped: both Credits loaders posted straight to the
/// server, so the tab was blank for anyone away from town.
///
/// This reads the source rather than exercising the client because
/// ApiService._http is a static final with no seam to inject a stub through.
/// The property that actually broke was structural — a method quietly not
/// routed through the cache — and that is what is checked here.
void main() {
  final source = File('lib/services/api_service.dart').readAsStringSync();

  /// The body of [method], from its signature to the closing of its `try`.
  String bodyOf(String method) {
    final start = source.indexOf('> $method(');
    expect(start, isNot(-1), reason: '$method no longer exists in ApiService');
    final next = source.indexOf('\n  /// ', start);
    return source.substring(start, next == -1 ? source.length : next);
  }

  /// Loaders behind a tab, with the noun a reader would recognise.
  const mustBeCached = <String, String>{
    'getSupervisorCredits': 'the Credits tab',
    'getSupervisorCustomers': 'a supervisor\'s customers, inside Credits',
  };

  mustBeCached.forEach((method, where) {
    test('$method serves a saved copy — it backs $where', () {
      expect(
        bodyOf(method),
        contains('_cachedGet'),
        reason: '$method backs $where, which is always on screen. '
            'Without a saved copy that tab shows a connection error and '
            'nothing else. If this endpoint genuinely must not be cached, '
            'the tab needs a specific explanation on screen, not a generic '
            'network failure.',
      );
    });
  });

  /// The other half of the bargain. Caching the list is only safe because the
  /// write is refused, so if the write ever starts queueing, the reasoning
  /// behind the cache above no longer holds and someone must revisit it.
  test('recording a credit payment is still refused offline', () {
    expect(
      bodyOf('addCreditPayment'),
      contains('OnlineOnly.creditPayment'),
      reason: 'The credit list is cached ONLY because a payment cannot be '
          'queued against a stale balance. If this write becomes queueable, '
          'revisit whether the balances it is sized against may be stale.',
    );
  });
}
