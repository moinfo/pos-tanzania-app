import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/receiving.dart';
import 'package:pos_tanzania_mobile/providers/receiving_provider.dart';

/// Main Store "Copy to Cart" must build the cart the way the web does
/// (Receiving_lib::add_item): add to what is there, one line per item and
/// location with quantities summed.
ReceivingItem line(int itemId, double qty, {int location = 15, double cost = 1000}) =>
    ReceivingItem(
      itemId: itemId,
      itemName: 'Item $itemId',
      line: 0,
      quantity: qty,
      costPrice: cost,
      unitPrice: cost,
      itemLocation: location,
    );

void main() {
  test('the same item from several sales becomes ONE line, quantities summed', () {
    final cart = ReceivingProvider();
    // SUKAR 50KG bought in three separate Main Store sales.
    cart.mergeReceivingItem(line(613, 2));
    cart.mergeReceivingItem(line(613, 4));
    cart.mergeReceivingItem(line(613, 6));
    expect(cart.cartItems.length, 1);
    expect(cart.cartItems.single.quantity, 12);
  });

  test('within one copy, different items each get their own line', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(100, 5));
    cart.mergeReceivingItem(line(200, 3));
    expect(cart.cartItems.map((c) => c.itemId), [100, 200]);
  });

  test('a new copy starts from an empty cart, keeping the supplier', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(100, 5)); // first copy
    cart.setReference('INV-1');
    cart.clearItems();                     // the next copy clears lines first
    cart.mergeReceivingItem(line(200, 3));
    expect(cart.cartItems.map((c) => c.itemId), [200]);
    expect(cart.reference, 'INV-1');
  });

  test('a return copied from Main Store keeps its negative quantity', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(514, -2)); // SM ORG x-2
    expect(cart.cartItems.single.quantity, -2);
    expect(cart.validateCart(), isNot(contains('quantity of 0')));
  });

  test('a return larger than its sale leaves a negative line', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(514, 3));
    cart.mergeReceivingItem(line(514, -5));
    expect(cart.cartItems.single.quantity, -2);
  });

  test('the stepper does not delete a negative line; it removes it at 0', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(514, -2));
    cart.decrementQuantity(0);
    expect(cart.cartItems.single.quantity, -3);
    cart.incrementQuantity(0);
    cart.incrementQuantity(0);
    expect(cart.cartItems.single.quantity, -1);
    cart.incrementQuantity(0);
    expect(cart.cartItems, isEmpty);
  });

  test('the same item at a different location stays a separate line', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(613, 2, location: 15));
    cart.mergeReceivingItem(line(613, 3, location: 9));
    expect(cart.cartItems.length, 2);
  });

  test('a return that cancels its sale removes the line instead of leaving 0', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(6204, 20));  // ASAS MILK sold
    cart.mergeReceivingItem(line(6204, -20)); // and returned
    expect(cart.cartItems, isEmpty);
  });

  test('a line keeps its first price when more of it is added, as the web does', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(613, 2, cost: 1000));
    cart.mergeReceivingItem(line(613, 3, cost: 999));
    expect(cart.cartItems.single.costPrice, 1000);
    expect(cart.cartItems.single.quantity, 5);
  });
}
