import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/item.dart';
import 'package:pos_tanzania_mobile/models/receiving.dart';
import 'package:pos_tanzania_mobile/providers/receiving_provider.dart';

/// Return mode must move stock the way the web's receivings register does:
/// Receivings::add negates the quantity outside 'receive'/'requisition', and
/// Receiving_lib::return_entire_receiving rebuilds the cart from a past
/// receiving with every quantity negated, at its original prices and stores.

/// Item has a long required-argument list; fromJson fills the defaults.
Item item(int id, {double cost = 1000, String variation = 'CTN', String? name}) =>
    Item.fromJson({
      'item_id': id,
      'name': name ?? 'Item $id',
      'item_number': 'N$id',
      'cost_price': cost,
      'unit_price': cost * 2,
      'variation': variation,
    });

ReceivingDetailItem detailLine(int id, double qty,
        {int? location, double cost = 1000}) =>
    ReceivingDetailItem(
      itemId: id,
      itemName: 'Item $id',
      itemNumber: 'N$id',
      description: '',
      serialNumber: '',
      itemLocation: location,
      quantity: qty,
      receivingQuantity: qty,
      costPrice: cost,
      unitPrice: cost * 2,
      discount: 0,
      discountType: 0,
      lineTotal: qty * cost,
    );

ReceivingDetails details(List<ReceivingDetailItem> items,
        {bool isReturn = false, int? returnedBy, double total = 0}) =>
    ReceivingDetails(
      receivingId: 8439,
      supplierId: 77,
      supplierName: 'SM ORG',
      employeeId: 1,
      receivingTime: '2026-09-27 10:00:00',
      paymentType: 'Credit Card',
      comment: '',
      reference: '',
      total: total,
      isReturn: isReturn,
      returnedBy: returnedBy,
      items: items,
    );

ReceivingListItem listRow({
  double totalCost = 88000,
  bool isReturn = false,
  int? returnedBy,
}) =>
    ReceivingListItem(
      receivingId: 8443,
      receivingTime: '2026-09-27 07:51:00',
      supplierId: 77,
      supplierName: 'MPINGA',
      employeeName: 'Clerk',
      paymentType: 'Credit Card',
      reference: '',
      totalItems: 1,
      totalCost: totalCost,
      isReturn: isReturn,
      returnedBy: returnedBy,
    );

void main() {
  test('Receive mode adds stock, Return mode takes it back out', () {
    final cart = ReceivingProvider()..setStockLocation(12);

    cart.addItem(item(613), quantity: 5);
    expect(cart.cartItems.single.quantity, 5);

    cart.clearItems();
    cart.setReturnMode(true);
    cart.addItem(item(613), quantity: 5);
    expect(cart.cartItems.single.quantity, -5);
  });

  test('a quantity typed as negative in Return mode is not double-negated', () {
    final cart = ReceivingProvider()
      ..setStockLocation(12)
      ..setReturnMode(true);
    cart.addItem(item(613), quantity: -5);
    expect(cart.cartItems.single.quantity, -5);
  });

  test('lines already in the cart keep their sign when the mode changes', () {
    // change_mode on the web does not touch the cart.
    final cart = ReceivingProvider()..setStockLocation(12);
    cart.addItem(item(613), quantity: 5);
    cart.setReturnMode(true);
    expect(cart.cartItems.single.quantity, 5);
    expect(cart.isReturn, isTrue);
  });

  test('returning a past receiving negates every line and takes its supplier', () {
    final cart = ReceivingProvider()..setStockLocation(12);
    cart.loadReceivingAsReturn(details([
      detailLine(613, 10, location: 15),
      detailLine(700, 2.5, location: 15),
    ]));

    expect(cart.isReturn, isTrue);
    expect(cart.cartItems.map((c) => c.quantity), [-10, -2.5]);
    // The store the stock went into is the store it comes back out of.
    expect(cart.cartItems.map((c) => c.itemLocation), [15, 15]);
    expect(cart.cartItems.map((c) => c.costPrice), [1000, 1000]);
    expect(cart.selectedSupplier?.supplierId, 77);
    expect(cart.reference, 'RECV 8439');
    expect(cart.cartItems.map((c) => c.line), [1, 2]);
  });

  test('returning a receiving replaces whatever was in the cart', () {
    // return_entire_receiving calls empty_cart() first.
    final cart = ReceivingProvider()..setStockLocation(12);
    cart.addItem(item(999), quantity: 3);
    cart.loadReceivingAsReturn(details([detailLine(613, 10, location: 15)]));
    expect(cart.cartItems.map((c) => c.itemId), [613]);
  });

  test('a receiving from an older server falls back to the chosen store', () {
    // item_location is null before the API returned it; the return still has
    // to name a store, so it uses the one the clerk is standing in.
    final cart = ReceivingProvider()..setStockLocation(12);
    cart.loadReceivingAsReturn(details([detailLine(613, 4)]),
        fallbackLocation: 21);
    expect(cart.cartItems.single.itemLocation, 21);
  });

  test('a negative cart passes validation and is sent as negative', () {
    final cart = ReceivingProvider()..setStockLocation(12);
    cart.loadReceivingAsReturn(details([detailLine(613, 10, location: 15)]));
    expect(cart.validateCart(), isNull);

    final payload = cart.createReceiving(employeeId: 1).toJson();
    final items = payload['items'] as List;
    expect((items.single as Map)['quantity'], -10);
  });

  test('completing a receiving puts the register back into Receive mode', () {
    // Receiving_lib::clear_all calls clear_mode().
    final cart = ReceivingProvider()..setStockLocation(12);
    cart.setReturnMode(true);
    cart.clearCart();
    expect(cart.isReturn, isFalse);
  });

  group('only cartons are received', () {
    test('a carton is receivable, a piece variant is not', () {
      expect(ReceivingProvider.isReceivable(item(6225)), isTrue);
      expect(ReceivingProvider.isReceivable(item(6226, variation: 'PC')), isFalse);
      // Whatever case or padding the row carries.
      expect(ReceivingProvider.isReceivable(item(1, variation: ' ctn ')), isTrue);
    });

    test('the refusal names the item and says why', () {
      // Item 6226 is the PC row whose name begins with a tab, so it sorted
      // above its own carton and was the row a clerk tapped. Completing the
      // delivery then failed with "Item with ID 6226 not found".
      final refusal = ReceivingProvider.receiveRefusal(
        item(6226, variation: 'PC', name: '\tPIPI PACKT KUBWA INDIA'),
      );
      expect(refusal, contains('PIPI PACKT KUBWA INDIA'));
      expect(refusal, contains('PC'));
      expect(refusal, contains('CTN'));
      expect(refusal, isNot(contains('not found')));
    });

    test('a piece variant is refused by the cart, not at Complete', () {
      final cart = ReceivingProvider()..setStockLocation(12);
      expect(
        () => cart.addItem(item(6226, variation: 'PC')),
        throwsA(isA<Exception>()),
      );
      expect(cart.cartItems, isEmpty);
      // The carton still goes in.
      cart.addItem(item(6225));
      expect(cart.cartItems.single.itemId, 6225);
    });
  });

  group('a return cannot be returned again', () {
    test('an ordinary receiving can be returned', () {
      expect(listRow().canBeReturned, isTrue);
      expect(details([detailLine(613, 4)], total: 88000).canBeReturned, isTrue);
    });

    test('a receiving that IS a return cannot', () {
      // RECV 8444: the -110,000 return of 8443. Returning it would put the
      // stock back, and could be repeated forever.
      expect(listRow(totalCost: -110000, isReturn: true).canBeReturned, isFalse);
      expect(
        details([detailLine(613, -5)], isReturn: true, total: -110000)
            .canBeReturned,
        isFalse,
      );
    });

    test('a receiving already returned cannot be returned a second time', () {
      // That would take the same stock out twice.
      expect(listRow(returnedBy: 8444).canBeReturned, isFalse);
      expect(details([detailLine(613, 4)], returnedBy: 8444).canBeReturned, isFalse);
    });

    test('a negative total alone is enough, for a server without the flags', () {
      expect(listRow(totalCost: -110000).canBeReturned, isFalse);
      expect(details([detailLine(613, -5)], total: -110000).canBeReturned, isFalse);
    });

    test('the flags parse from what the API sends', () {
      final row = ReceivingListItem.fromJson({
        'receiving_id': 8444,
        'total_cost': -110000,
        'is_return': true,
        'returned_by': null,
      });
      expect(row.isReturn, isTrue);
      expect(row.returnedBy, isNull);

      final returned = ReceivingListItem.fromJson({
        'receiving_id': 8443,
        'total_cost': 88000,
        'is_return': false,
        'returned_by': 8444,
      });
      expect(returned.returnedBy, 8444);
      expect(returned.canBeReturned, isFalse);

      // A server that predates the flags sends neither.
      final old = ReceivingListItem.fromJson({
        'receiving_id': 8439,
        'total_cost': 13853800,
      });
      expect(old.isReturn, isFalse);
      expect(old.canBeReturned, isTrue);
    });
  });
}
