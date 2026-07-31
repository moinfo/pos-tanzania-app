import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/one_time_discount.dart';

OneTimeDiscount buildDiscount({
  double quantity = 10,
  double discountAmount = 500,
  String status = 'active',
}) {
  return OneTimeDiscount(
    discountId: 1,
    documentNumber: 'OTD-001',
    customerId: 7,
    itemId: 42,
    stockLocationId: 19,
    quantity: quantity,
    discountAmount: discountAmount,
    validDate: '2026-07-31',
    status: status,
  );
}

void main() {
  group('isValidForQuantity', () {
    test('applies on an exact match', () {
      expect(buildDiscount(quantity: 10).isValidForQuantity(10), isTrue);
    });

    test('rejects quantities above or below the approved amount', () {
      final d = buildDiscount(quantity: 10);
      expect(d.isValidForQuantity(9), isFalse);
      expect(d.isValidForQuantity(11), isFalse);
      expect(d.isValidForQuantity(0), isFalse);
    });

    test('tolerates float drift within 0.001, matching the web register', () {
      // DECIMAL(15,3) round-trips can land a hair off an exact double
      final d = buildDiscount(quantity: 2.5);
      expect(d.isValidForQuantity(2.5000004), isTrue);
      expect(d.isValidForQuantity(2.4999996), isTrue);
      // Still rejects a genuinely different quantity
      expect(d.isValidForQuantity(2.51), isFalse);
    });

    test('0.1 + 0.2 style accumulation still matches', () {
      final d = buildDiscount(quantity: 0.3);
      expect(d.isValidForQuantity(0.1 + 0.2), isTrue);
    });
  });

  group('getTotalDiscountAmount', () {
    test('returns per-unit amount times approved quantity when valid', () {
      final d = buildDiscount(quantity: 10, discountAmount: 500);
      expect(d.getTotalDiscountAmount(10), 5000);
    });

    test('returns zero when the quantity does not qualify', () {
      final d = buildDiscount(quantity: 10, discountAmount: 500);
      expect(d.getTotalDiscountAmount(9), 0);
      expect(d.getTotalDiscountAmount(11), 0);
    });
  });

  group('fromJson', () {
    test('parses the check endpoint payload with string numerics', () {
      final response = CheckDiscountResponse.fromJson({
        'available': true,
        'discount': {
          'discount_id': '3',
          'discount_amount': '500.00',
          'quantity': '10.000',
          'document_number': 'OTD-003',
          'valid_date': '2026-07-31',
          'status': 'active',
        },
      });

      expect(response.available, isTrue);
      expect(response.discount!.discountId, 3);
      expect(response.discount!.discountAmount, 500.0);
      expect(response.discount!.quantity, 10.0);
      expect(response.discount!.status, 'active');
      expect(response.discount!.isValidForQuantity(10), isTrue);
    });

    test('handles the not-available response', () {
      final response = CheckDiscountResponse.fromJson({
        'available': false,
        'discount': null,
      });

      expect(response.available, isFalse);
      expect(response.discount, isNull);
    });
  });
}
