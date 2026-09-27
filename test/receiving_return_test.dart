import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/item.dart';
import 'package:pos_tanzania_mobile/models/receiving.dart';
import 'package:pos_tanzania_mobile/providers/receiving_provider.dart';

/// Return mode must move stock the way the web's receivings register does:
/// Receivings::add negates the quantity outside 'receive'/'requisition', and
/// Receiving_lib::return_entire_receiving rebuilds the cart from a past
/// receiving with every quantity negated, at its original prices and stores.

/// Item has a long required-argument list; fromJson fills the defaults.
Item item(int id, {double cost = 1000}) => Item.fromJson({
      'item_id': id,
      'name': 'Item $id',
      'item_number': 'N$id',
      'cost_price': cost,
      'unit_price': cost * 2,
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

ReceivingDetails details(List<ReceivingDetailItem> items) => ReceivingDetails(
      receivingId: 8439,
      supplierId: 77,
      supplierName: 'SM ORG',
      employeeId: 1,
      receivingTime: '2026-09-27 10:00:00',
      paymentType: 'Credit Card',
      comment: '',
      reference: '',
      total: 0,
      items: items,
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
}
