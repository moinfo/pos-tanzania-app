import 'package:flutter/foundation.dart';
import '../models/receiving.dart';
import '../models/item.dart';
import '../models/supplier.dart';
import '../l10n/lang.dart';

class ReceivingProvider with ChangeNotifier {
  // Cart items
  final List<ReceivingItem> _cartItems = [];

  // Selected supplier
  Supplier? _selectedSupplier;

  // Payment type
  String _paymentType = 'Cash'; // Cash, Credit Card, Due

  // Reference/comment
  String? _reference;
  String? _comment;

  // Stock location (will be set from LocationProvider)
  int? _stockLocation;

  // Getters
  List<ReceivingItem> get cartItems => _cartItems;
  Supplier? get selectedSupplier => _selectedSupplier;
  String get paymentType => _paymentType;
  String? get reference => _reference;
  String? get comment => _comment;
  int? get stockLocation => _stockLocation;

  // Cart metrics
  int get itemCount => _cartItems.length;

  double get total {
    return _cartItems.fold(0.0, (sum, item) => sum + item.calculateTotal());
  }

  double get totalQuantity {
    return _cartItems.fold(0.0, (sum, item) => sum + item.quantity);
  }

  bool get hasItems => _cartItems.isNotEmpty;

  /// Stock is delivered in cartons. A PC row is the piece variant of a
  /// carton item, and the receiving refuses it outright -- Item::exists()
  /// and Item::get_info() both filter variation = 'CTN', which is why every
  /// one of the 190,729 receiving lines on record is a carton.
  ///
  /// The refusal used to arrive at Complete, as "Item with ID 6226 not
  /// found", with the delivery already counted into the cart.
  static bool isReceivable(Item item) =>
      item.variation.trim().toUpperCase() == 'CTN';

  /// Why this item cannot be received, or null if it can.
  static String? receiveRefusal(Item item) => isReceivable(item)
      ? null
      : '${item.name.trim()} is a ${item.variation.trim()}. '
          'Stock is received in cartons (CTN).';

  // Add item to cart
  void addItem(Item item, {double quantity = 1, double? costPrice}) {
    // Ensure stock location is set before adding items
    if (_stockLocation == null) {
      throw Exception('Stock location must be set before adding items');
    }

    // The backstop, for a server that has not been given the filter yet.
    final refusal = receiveRefusal(item);
    if (refusal != null) {
      throw Exception(refusal);
    }

    // In Return mode every line goes in negative, as the web does
    // (Receivings::add negates the quantity outside 'receive').
    if (_isReturn) {
      quantity = -quantity.abs();
    }

    // Check if item already exists in cart
    final existingIndex = _cartItems.indexWhere((i) => i.itemId == item.itemId);

    if (existingIndex >= 0) {
      // Update quantity if item exists
      final existingItem = _cartItems[existingIndex];
      _cartItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
    } else {
      // Get stock for selected location
      double locationStock = 0;
      if (item.quantityByLocation != null && item.quantityByLocation!.containsKey(_stockLocation)) {
        locationStock = item.quantityByLocation![_stockLocation!] ?? 0;
      }

      // Add new item
      final receivingItem = ReceivingItem(
        itemId: item.itemId,
        itemName: item.name,
        itemNumber: item.itemNumber,
        line: _cartItems.length + 1,
        quantity: quantity,
        costPrice: costPrice ?? item.costPrice,
        unitPrice: item.unitPrice,
        itemLocation: _stockLocation!,
        availableStock: locationStock, // Store location-specific stock
      );
      _cartItems.add(receivingItem);
    }

    notifyListeners();
  }

  /// Add an item the way the web cart does (Receiving_lib::add_item): the
  /// same item at the same stock location is ONE line whose quantity grows,
  /// and nothing already in the cart is touched.
  ///
  /// Main Store copies used to replace the whole cart and add a separate line
  /// per sale -- so copying sale A then sale B kept only B, and an item bought
  /// in five sales came in as five lines.
  ///
  /// Negative quantities are kept: a Main Store return (SM ORG x-2) is
  /// received as -2, taking the stock back out, as the web does. Only a line
  /// that nets to exactly zero -- a return cancelling its own sale -- is
  /// dropped, because it moves nothing.
  void mergeReceivingItem(ReceivingItem item) {
    final index = _cartItems.indexWhere(
      (c) => c.itemId == item.itemId && c.itemLocation == item.itemLocation,
    );

    if (index >= 0) {
      final merged = _cartItems[index].quantity + item.quantity;
      if (merged == 0) {
        _cartItems.removeAt(index);
        _renumber();
      } else {
        // The existing line keeps its price, as the web's does.
        _cartItems[index] = _cartItems[index].copyWith(quantity: merged);
      }
    } else if (item.quantity != 0) {
      _cartItems.add(item.copyWith(line: _cartItems.length + 1));
    }
    notifyListeners();
  }

  /// Receiving stock (false) or returning it to the supplier (true) -- the
  /// web's Receive / Return mode on the receivings register.
  ///
  /// In Return mode an item added goes in negative, so completing it takes
  /// the stock back out. The cart is left alone when the mode changes, as on
  /// the web: a line already entered keeps the sign it was entered with.
  bool get isReturn => _isReturn;
  bool _isReturn = false;

  /// The receiving this cart is returning, when it was loaded from one.
  ///
  /// It is sent with the receiving so the server can cap the return against
  /// it. The reference carries the same thing, but a clerk can type over a
  /// reference, and that must not quietly uncap anything.
  int? get returnOfReceivingId => _returnOfReceivingId;
  int? _returnOfReceivingId;

  void setReturnMode(bool value) {
    if (_isReturn == value) return;
    _isReturn = value;
    if (!value) _returnOfReceivingId = null;
    notifyListeners();
  }

  /// Load a past receiving as a return: the same items, at their original
  /// prices and stores, with the quantities negated -- the web's
  /// Receiving_lib::return_entire_receiving.
  ///
  /// What goes in is the BALANCE, not what was received: 50 received and 30
  /// already returned puts in 20, because 20 is all that is left to take.
  /// An item with nothing left is left out entirely.
  ///
  /// [selected] narrows it to the items the clerk picked, keyed
  /// "itemId:itemLocation" with the quantity chosen for each. A receiving of
  /// 50 items where two are coming back should not put 50 lines in the cart
  /// for 48 of them to be deleted one at a time. Null means all of it.
  ///
  /// The cart is emptied first, exactly as the web does, so what is returned
  /// is that receiving and nothing else. The supplier comes from it too.
  void loadReceivingAsReturn(
    ReceivingDetails details, {
    int? fallbackLocation,
    Map<String, double>? selected,
  }) {
    _cartItems.clear();
    _isReturn = true;
    _returnOfReceivingId = details.receivingId;

    _selectedSupplier = Supplier(
      supplierId: details.supplierId,
      companyName: details.supplierName,
      firstName: '',
      lastName: '',
      displayName: details.supplierName,
      // Balances are display fields the receiving flow never reads; the
      // supplier picker refreshes them when it is opened.
      credit: 0,
      debit: 0,
      balance: 0,
    );
    _reference = 'RECV ${details.receivingId}';

    for (final row in details.returnableLines) {
      final key = '${row.itemId}:${row.itemLocation}';
      final chosen = selected == null ? row.returnable : (selected[key] ?? 0);
      if (chosen <= 0 || row.returnable <= 0) continue;

      // Never past the balance, whatever was asked for.
      final quantity = chosen > row.returnable ? row.returnable : chosen;

      _cartItems.add(ReceivingItem(
        itemId: row.itemId,
        itemName: row.itemName,
        line: _cartItems.length + 1,
        quantity: -quantity,
        costPrice: row.costPrice,
        unitPrice: row.unitPrice,
        itemLocation: row.itemLocation != 0
            ? row.itemLocation
            : (fallbackLocation ?? _stockLocation ?? 1),
        returnLimit: row.returnable,
      ));
    }
    notifyListeners();
  }

  /// Empty the cart's LINES, keeping the supplier, reference and comment.
  ///
  /// Main Store copies start from an empty cart, so a second copy replaces
  /// the first instead of piling on top of it. clearCart() would also wipe
  /// the supplier the clerk already picked, which the copy has no reason to.
  void clearItems() {
    _cartItems.clear();
    notifyListeners();
  }

  void _renumber() {
    for (var i = 0; i < _cartItems.length; i++) {
      _cartItems[i] = _cartItems[i].copyWith(line: i + 1);
    }
  }

  // Add ReceivingItem directly to cart
  void addReceivingItem(ReceivingItem item) {
    final receivingItem = item.copyWith(line: _cartItems.length + 1);
    _cartItems.add(receivingItem);
    notifyListeners();
  }

  // Update item quantity
  void updateQuantity(int index, double quantity) {
    if (index >= 0 && index < _cartItems.length) {
      // A line returning a past receiving stops at what that receiving
      // brought in: 50 received cannot become 51 returned, which would take
      // out stock nobody ever delivered.
      quantity = _cartItems[index].clampToReturnLimit(quantity);

      // Zero removes the line. Below zero is a real quantity -- a return
      // copied from Main Store -- and must survive the stepper; it used to
      // delete such a line on the first tap.
      if (quantity == 0) {
        removeItem(index);
      } else {
        _cartItems[index] = _cartItems[index].copyWith(quantity: quantity);
        notifyListeners();
      }
    }
  }

  /// This line is already returning everything that was received.
  bool isAtReturnLimit(int index) {
    if (index < 0 || index >= _cartItems.length) return false;
    final item = _cartItems[index];
    return item.returnLimit != null &&
        item.quantity <= -item.returnLimit!.abs();
  }

  // Update item cost price
  void updateCostPrice(int index, double costPrice) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index] = _cartItems[index].copyWith(costPrice: costPrice);
      notifyListeners();
    }
  }

  // Update item unit price (selling price)
  void updateUnitPrice(int index, double unitPrice) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index] = _cartItems[index].copyWith(unitPrice: unitPrice);
      notifyListeners();
    }
  }

  // Remove item from cart
  void removeItem(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      // Update line numbers
      for (int i = 0; i < _cartItems.length; i++) {
        _cartItems[i] = _cartItems[i].copyWith(line: i + 1);
      }
      notifyListeners();
    }
  }

  // Clear cart
  void clearCart() {
    _cartItems.clear();
    _selectedSupplier = null;
    _reference = null;
    _comment = null;
    // Back to Receive, as the web's Receiving_lib::clear_all does through
    // clear_mode(): the clerk who just booked a return should not find the
    // next delivery silently going in negative.
    _isReturn = false;
    _returnOfReceivingId = null;
    notifyListeners();
  }

  // Set supplier
  void setSupplier(Supplier? supplier) {
    _selectedSupplier = supplier;
    notifyListeners();
  }

  // Set payment type
  void setPaymentType(String type) {
    _paymentType = type;
    notifyListeners();
  }

  // Set reference
  void setReference(String? ref) {
    _reference = ref;
    notifyListeners();
  }

  // Set comment
  void setComment(String? comm) {
    _comment = comm;
    notifyListeners();
  }

  // Set stock location
  void setStockLocation(int? location) {
    _stockLocation = location;
    notifyListeners();
  }

  // Create receiving from cart
  Receiving createReceiving({int? employeeId}) {
    if (_stockLocation == null) {
      throw Exception('Stock location must be set before creating receiving');
    }

    return Receiving(
      supplierId: _selectedSupplier!.supplierId,
      employeeId: employeeId,
      comment: _comment,
      reference: _reference,
      paymentType: _paymentType,
      stockLocation: _stockLocation!,
      items: _cartItems,
      returnOf: _returnOfReceivingId,
    );
  }

  // Get item by ID from cart
  ReceivingItem? getItemById(int itemId) {
    try {
      return _cartItems.firstWhere((item) => item.itemId == itemId);
    } catch (e) {
      return null;
    }
  }

  // Check if item is in cart
  bool isInCart(int itemId) {
    return _cartItems.any((item) => item.itemId == itemId);
  }

  // Get cart item quantity for specific item
  double getItemQuantity(int itemId) {
    final item = getItemById(itemId);
    return item?.quantity ?? 0;
  }

  // Increment item quantity
  void incrementQuantity(int index) {
    if (index >= 0 && index < _cartItems.length) {
      final currentQty = _cartItems[index].quantity;
      updateQuantity(index, currentQty + 1);
    }
  }

  // Decrement item quantity
  void decrementQuantity(int index) {
    if (index >= 0 && index < _cartItems.length) {
      final currentQty = _cartItems[index].quantity;
      updateQuantity(index, currentQty - 1);
    }
  }

  // Quick add item with default quantity
  void quickAddItem(Item item) {
    addItem(item, quantity: 1);
  }

  // Validate cart before creating receiving
  String? validateCart() {
    if (_cartItems.isEmpty) {
      return 'Cart is empty. Add items to continue.';
    }

    if (_selectedSupplier == null) {
      return 'Please select a supplier.'.tr;
    }

    if (_stockLocation == null) {
      return 'Stock location is not set. Please go back and try again.'.tr;
    }

    // Zero is meaningless; a negative quantity is a return and is allowed,
    // as on the web.
    for (var item in _cartItems) {
      if (item.quantity == 0) {
        return 'Item "${item.itemName}" has a quantity of 0.';
      }
      if (item.costPrice < 0) {
        return 'Item "${item.itemName}" has invalid cost price.'.tr;
      }
      if (item.exceedsReturnLimit) {
        return '"${item.itemName}": only ${_plain(item.returnLimit!)} were '
            'received, so at most ${_plain(item.returnLimit!)} can be returned.';
      }
    }

    return null; // Valid
  }

  /// 50, not 50.0 -- these numbers are read out loud at a counter.
  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  // Get cart summary
  Map<String, dynamic> getCartSummary() {
    return {
      'item_count': itemCount,
      'total_quantity': totalQuantity,
      'total_cost': total,
      'supplier': _selectedSupplier?.companyName ?? 'No supplier',
      'payment_type': _paymentType,
    };
  }
}
