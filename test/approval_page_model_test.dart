import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/approval.dart';

/// Parses real /approvals responses captured from the dev server against the
/// live Leruma database, so the date-scope metadata the two screens rely on is
/// tested against what the server actually sends, not a hand-written shape.
void main() {
  Map<String, dynamic> data(String name) => (jsonDecode(
        File('test/fixtures/$name.json').readAsStringSync(),
      ) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

  test('the pending queue page parses, with its date metadata', () {
    final page = ApprovalPage.fromJson(data('approvals_pending'), 'approvals');

    expect(page.approvals, isNotEmpty);
    expect(page.total, greaterThan(0));
    // Fetched over 2000-2100, so the filtered total equals the backlog.
    expect(page.total, equals(page.totalAllDates));
    expect(page.hiddenByDate, equals(0));
    expect(page.canFilterDate, isTrue);
    expect(page.dateScopeUniform, isTrue);
    expect(page.dateScope, hasLength(2));

    // Numbers arrive from MySQL as strings; the model must parse, not cast.
    for (final approval in page.approvals) {
      expect(approval.approvalId, greaterThan(0));
      expect(approval.modelType, isNotEmpty);
    }
  });

  test('a half-entitled caller yields a non-uniform scope, exposed per model',
      () {
    final page = ApprovalPage.fromJson(
        data('approvals_my_requests_split'), 'requests');

    expect(page.dateScopeUniform, isFalse);

    // One model was widened, the other pinned to today.
    final pinned = page.pinnedToToday;
    expect(pinned, hasLength(1));
    expect(pinned.single.modelType, equals('One_time_discount'));

    final widened =
        page.dateScope.where((s) => s.canFilterDate).map((s) => s.modelType);
    expect(widened, contains('Customer_credit_limit'));
  });

  test('hiddenByDate never goes negative', () {
    const page = ApprovalPage(total: 5, totalAllDates: 3);
    expect(page.hiddenByDate, equals(0));
  });
}
