import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/approval.dart';

/// Parses real responses captured from the dev server against the live Leruma
/// database, not hand-written fixtures.
///
/// This exists because of one specific hazard: the MySQL driver hands numbers
/// back as strings, so `credit_amount` arrives as "500000.00" and
/// `is_current` as "1". A model that casts instead of parsing compiles fine
/// and then throws on the first row a seller sees.
void main() {
  Map<String, dynamic> fixture(String name) => (jsonDecode(
        File('test/fixtures/credit_limit_$name.json').readAsStringSync(),
      ) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

  test('the list page parses, numbers and all', () {
    final page = CreditLimitPage.fromJson(fixture('requests'));

    expect(page.total, greaterThan(0));
    expect(page.rows, isNotEmpty);
    expect(page.locations, isNotEmpty);
    expect(page.canFilterDate, isTrue);

    for (final row in page.rows) {
      expect(row.creditLimitId, greaterThan(0));
      expect(row.documentNumber, isNotEmpty);
      expect(row.creditAmount, greaterThan(0));
      expect(row.customerName, isNotNull);
    }
  });

  test('a record stored as "pending" but long since settled reads as settled',
      () {
    final page = CreditLimitPage.fromJson(fixture('requests'));
    final stale = page.rows.where((r) => r.statusIsStale);

    for (final row in stale) {
      // The whole point of the derived status: the stored column says
      // pending, the badge must not.
      expect(row.storedStatus, 'pending');
      expect(row.outcome, isNot(CreditLimitOutcome.awaiting));
      expect(row.outcome, isNot(CreditLimitOutcome.unreviewed));
    }
  });

  test('statistics parse and the buckets add up to the total', () {
    final data = fixture('stats')['statistics'] as Map<String, dynamic>;
    final stats = CreditLimitStatistics.fromJson(data);

    expect(stats.total, greaterThan(0));
    expect(
      stats.awaiting +
          stats.approved +
          stats.rejected +
          stats.returned +
          stats.cancelled +
          stats.unreviewed,
      stats.total,
      reason: 'the six outcomes must partition the set exactly once',
    );
    expect(stats.totalAmount, greaterThanOrEqualTo(stats.approvedAmount));
  });

  test('a customer history parses, including who decided each record', () {
    final history = CustomerCreditHistory.fromJson(fixture('history'));

    expect(history.customer.customerId, greaterThan(0));
    expect(history.customer.customerName, isNotEmpty);
    expect(history.history, isNotEmpty);
    expect(history.statistics.total,
        greaterThanOrEqualTo(history.history.length));

    // approved_by is NULL on every historical record -- the step that would
    // have written it is the one the triggers broke -- so the decision has to
    // come off the approval trail instead.
    final settled = history.history
        .where((r) => r.outcome == CreditLimitOutcome.approved && r.approvalId != null);
    if (settled.isNotEmpty) {
      expect(settled.first.decidedByName, isNotNull);
    }
  });

  test('unused allowances parse and every one is worth something', () {
    final unused = UnusedAllowanceList.fromJson(fixture('unused'));

    expect(unused.customers, isNotEmpty);
    expect(unused.totalAmount, greaterThan(0));
    for (final customer in unused.customers) {
      expect(customer.oneTimeLimit, greaterThan(0),
          reason: 'a zero allowance grants nothing and must not be listed');
      expect(customer.customerName, isNotEmpty);
    }
    expect(
      unused.customers.fold<double>(0, (sum, c) => sum + c.oneTimeLimit),
      closeTo(unused.totalAmount, 0.01),
    );
  });

  test('the scoped customer picker carries what a request turns on', () {
    final list = (fixture('customers')['customers'] as List)
        .whereType<Map<String, dynamic>>()
        .map(CreditScopedCustomer.fromJson)
        .toList();

    expect(list, isNotEmpty);
    for (final customer in list) {
      expect(customer.customerId, greaterThan(0));
      // currentBalance is the figure the row leads with; it must parse even
      // when the server sends it as a bare 0 rather than "0.00".
      expect(customer.currentBalance, isA<double>());
      // holdsAllowance needs BOTH halves: the flag alone is set on 57
      // customers whose amount is zero.
      if (customer.holdsAllowance) {
        expect(customer.hasOneTimeCredit, isTrue);
        expect(customer.oneTimeCreditLimit, greaterThan(0));
      }
    }
  });
}
