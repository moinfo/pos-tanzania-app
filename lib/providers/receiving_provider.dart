import 'package:flutter/foundation.dart';
import '../models/receiving.dart';
import '../models/item.dart';
import '../models/supplier.dart';

class ReceivingProvider with ChangeNotifier {
  // Cart items
  List<ReceivingItem> _cartItems = [];

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

  // Add item to cart
  void addItem(Item item, {double quantity = 1, double? costPrice}) {
    // Ensure stock location is set before adding items
    if (_stockLocation == null) {
      throw Exception('Stock location must be set before adding items');
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

  // Add ReceivingItem directly to cart
  void addReceivingItem(ReceivingItem item) {
    final receivingItem = item.copyWith(line: _cartItems.length + 1);
    _cartItems.add(receivingItem);
    notifyListeners();
  }

  // Update item quantity
  void updateQuantity(int index, double quantity) {
    if (index >= 0 && index < _cartItems.length) {
      if (quantity <= 0) {
        removeItem(index);
      } else {
        _cartItems[index] = _cartItems[index].copyWith(quantity: quantity);
        notifyListeners();
      }
    }
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
      return 'Please select a supplier.';
    }

    if (_stockLocation == null) {
      return 'Stock location is not set. Please go back and try again.';
    }

    // Check for items with zero or negative quantity
    for (var item in _cartItems) {
      if (item.quantity <= 0) {
        return 'Item "${item.itemName}" has invalid quantity.';
      }
      if (item.costPrice < 0) {
        return 'Item "${item.itemName}" has invalid cost price.';
      }
    }

    return null; // Valid
  }

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
