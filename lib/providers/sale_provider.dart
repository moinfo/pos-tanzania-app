import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../models/item.dart';
import '../models/customer.dart';

class SaleProvider with ChangeNotifier {
  // Cart items
  List<SaleItem> _cartItems = [];

  // Selected customer
  Customer? _selectedCustomer;

  // Payment type
  String _paymentType = 'Cash'; // Cash, Credit Card, Credit, Due

  // Multiple payments list
  List<SalePayment> _payments = [];

  // Getters
  List<SaleItem> get cartItems => _cartItems;
  Customer? get selectedCustomer => _selectedCustomer;
  String get paymentType => _paymentType;
  List<SalePayment> get payments => _payments;

  // Cart metrics
  int get itemCount => _cartItems.length;

  double get subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  double get totalDiscount {
    return _cartItems.fold(0.0, (sum, item) {
      final itemSubtotal = item.quantity * item.unitPrice;
      final itemDiscount = item.discountType == 0
          ? (itemSubtotal * item.discount / 100)
          : item.discount;
      return sum + itemDiscount;
    });
  }

  double get total {
    return subtotal - totalDiscount;
  }

  bool get hasItems => _cartItems.isNotEmpty;

  // Payment metrics
  double get totalPayments {
    return _payments.fold(0.0, (sum, payment) => sum + payment.amount);
  }

  double get amountDue {
    return total - totalPayments;
  }

  bool get hasPayments => _payments.isNotEmpty;

  bool get isFullyPaid => amountDue <= 0;

  // Stock location (will be set from LocationProvider)
  int? _stockLocation;

  // Getter for stock location
  int? get stockLocation => _stockLocation;

  // Set stock location
  void setStockLocation(int locationId) {
    _stockLocation = locationId;
    notifyListeners();
  }

  // Add item to cart
  void addItem(Item item, {double quantity = 1, int? locationId}) {
    // Use provided locationId or fall back to stored location or default
    final itemLocationId = locationId ?? _stockLocation ?? 1;

    // Check if item already exists in cart
    final existingIndex = _cartItems.indexWhere((i) => i.itemId == item.itemId);

    if (existingIndex >= 0) {
      // Update quantity if item exists
      final existingItem = _cartItems[existingIndex];
      _cartItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
    } else {
      // Add new item
      final saleItem = SaleItem(
        itemId: item.itemId,
        itemName: item.name,
        line: _cartItems.length + 1,
        quantity: quantity,
        costPrice: item.costPrice,
        unitPrice: item.unitPrice,
        discount: 0,
        discountType: 0, // Percentage
        discountLimit: item.discountLimit,
        stockLocationId: itemLocationId, // Use selected location
        availableStock: item.quantity, // Store available stock for display
      );
      _cartItems.add(saleItem);
    }

    notifyListeners();
  }

  // Add SaleItem directly to cart (used for resuming suspended sales)
  void addSaleItem(SaleItem item) {
    final saleItem = item.copyWith(line: _cartItems.length + 1);
    _cartItems.add(saleItem);
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

  // Update item price
  void updatePrice(int index, double price) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index] = _cartItems[index].copyWith(unitPrice: price);
      notifyListeners();
    }
  }

  // Update item discount
  void updateDiscount(int index, double discount, {int discountType = 0}) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index] = _cartItems[index].copyWith(
        discount: discount,
        discountType: discountType,
      );
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
    _selectedCustomer = null;
    _payments.clear();
    notifyListeners();
  }

  // Set customer
  void setCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  // Set payment type
  void setPaymentType(String type) {
    _paymentType = type;
    notifyListeners();
  }

  // Payment management methods
  void addPayment(SalePayment payment) {
    _payments.add(payment);
    notifyListeners();
  }

  void removePayment(int index) {
    if (index >= 0 && index < _payments.length) {
      _payments.removeAt(index);
      notifyListeners();
    }
  }

  void clearPayments() {
    _payments.clear();
    notifyListeners();
  }

  // Create sale from cart
  Sale createSale({
    List<SalePayment>? payments,
    String? comment,
    int saleType = 0,
  }) {
    return Sale(
      saleTime: DateTime.now().toIso8601String(),
      customerId: _selectedCustomer?.personId,
      employeeId: 0, // Will be set from auth provider
      comment: comment,
      saleStatus: 0, // Completed
      saleType: saleType,
      subtotal: subtotal,
      taxTotal: 0,
      total: total,
      items: _cartItems,
      payments: payments ?? _payments, // Use accumulated payments if not provided
    );
  }

  // Load suspended sale
  void loadSuspendedSale(Sale sale) {
    _cartItems = sale.items ?? [];
    _selectedCustomer = null; // Customer info is in the sale object
    notifyListeners();
  }

  // Get item by ID from cart
  SaleItem? getItemById(int itemId) {
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

  // Get cart item count for specific item
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

  // Validate cart before checkout
  String? validateCart() {
    if (_cartItems.isEmpty) {
      return 'Cart is empty. Add items to continue.';
    }

    // Check for items with zero or negative quantity
    for (var item in _cartItems) {
      if (item.quantity <= 0) {
        return 'Item "${item.itemName}" has invalid quantity.';
      }
      if (item.unitPrice < 0) {
        return 'Item "${item.itemName}" has invalid price.';
      }
    }

    return null; // Valid
  }

  // Get cart summary
  Map<String, dynamic> getCartSummary() {
    return {
      'item_count': itemCount,
      'total_items': _cartItems.fold<double>(0, (sum, item) => sum + item.quantity),
      'subtotal': subtotal,
      'discount': totalDiscount,
      'total': total,
      'customer': _selectedCustomer?.fullName ?? 'Walk-in',
    };
  }

  // Apply discount to entire cart (future enhancement)
  void applyCartDiscount(double discountPercent) {
    for (int i = 0; i < _cartItems.length; i++) {
      _cartItems[i] = _cartItems[i].copyWith(
        discount: discountPercent,
        discountType: 0, // Percentage
      );
    }
    notifyListeners();
  }

  // Remove discount from cart
  void removeCartDiscount() {
    for (int i = 0; i < _cartItems.length; i++) {
      _cartItems[i] = _cartItems[i].copyWith(discount: 0);
    }
    notifyListeners();
  }
}
