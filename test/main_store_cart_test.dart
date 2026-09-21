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

  test('copying sale B keeps what sale A already put in the cart', () {
    final cart = ReceivingProvider();
    cart.mergeReceivingItem(line(100, 5)); // sale A
    cart.mergeReceivingItem(line(200, 3)); // sale B
    expect(cart.cartItems.map((c) => c.itemId), [100, 200]);
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
