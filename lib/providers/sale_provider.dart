import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/one_time_discount.dart';
import '../models/item_quantity_offer.dart';
import '../services/api_service.dart';
import '../providers/offline_provider.dart';

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
    // Always use fixed discount (not percentage)
    return _cartItems.fold(0.0, (sum, item) => sum + item.discount);
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

  // One-time discounts tracking (itemId -> OneTimeDiscount)
  final Map<int, OneTimeDiscount> _oneTimeDiscounts = {};

  // API service instance
  final ApiService _apiService = ApiService();

  // Get one-time discount for an item
  OneTimeDiscount? getOneTimeDiscount(int itemId) {
    return _oneTimeDiscounts[itemId];
  }

  // Check if item has one-time discount applied (quantity must meet threshold)
  bool hasOneTimeDiscount(int itemId) {
    if (!_oneTimeDiscounts.containsKey(itemId)) {
      return false;
    }

    // Check if quantity meets the discount requirement
    final discount = _oneTimeDiscounts[itemId]!;
    final cartItem = _cartItems.firstWhere(
      (item) => item.itemId == itemId,
      orElse: () => SaleItem(
        itemId: itemId,
        itemName: '',
        line: 0,
        quantity: 0,
        costPrice: 0,
        unitPrice: 0,
      ),
    );

    return discount.isValidForQuantity(cartItem.quantity);
  }

  // Check if item has pending one-time discount (available but quantity not met)
  bool hasPendingOneTimeDiscount(int itemId) {
    if (!_oneTimeDiscounts.containsKey(itemId)) {
      return false;
    }

    // Check if quantity does NOT meet the discount requirement
    final discount = _oneTimeDiscounts[itemId]!;
    final cartItem = _cartItems.firstWhere(
      (item) => item.itemId == itemId,
      orElse: () => SaleItem(
        itemId: itemId,
        itemName: '',
        line: 0,
        quantity: 0,
        costPrice: 0,
        unitPrice: 0,
      ),
    );

    return !discount.isValidForQuantity(cartItem.quantity);
  }

  // Get required quantity for one-time discount
  double? getOneTimeDiscountRequiredQty(int itemId) {
    return _oneTimeDiscounts[itemId]?.quantity;
  }

  // Get all applied one-time discount IDs (for marking as used)
  List<int> getAppliedDiscountIds() {
    return _oneTimeDiscounts.values.map((d) => d.discountId).toList();
  }

  // Quantity offers tracking (itemId -> ItemQuantityOffer)
  final Map<int, ItemQuantityOffer> _quantityOffers = {};

  // Get quantity offer for an item
  ItemQuantityOffer? getQuantityOffer(int itemId) {
    return _quantityOffers[itemId];
  }

  // Check if item has quantity offer
  bool hasQuantityOffer(int itemId) {
    return _quantityOffers.containsKey(itemId);
  }

  // Get all applied quantity offer data for redemption
  List<Map<String, dynamic>> getAppliedOffers() {
    final List<Map<String, dynamic>> appliedOffers = [];

    for (var entry in _quantityOffers.entries) {
      final itemId = entry.key;
      final offer = entry.value;

      // Find the cart item to get purchased quantity
      final cartItem = _cartItems.firstWhere(
        (item) => item.itemId == itemId,
        orElse: () => SaleItem(
          itemId: itemId,
          itemName: '',
          line: 0,
          quantity: 0,
          costPrice: 0,
          unitPrice: 0,
          discount: 0,
          discountType: 1,
          stockLocationId: _stockLocation ?? 1,
        ),
      );

      if (cartItem.quantity > 0) {
        // Calculate the reward
        final freeQty = offer.calculateReward(cartItem.quantity);

        if (freeQty > 0) {
          appliedOffers.add({
            'offer_id': offer.offerId,
            'item_id': itemId,
            'purchased_quantity': cartItem.quantity,
            'reward_quantity': freeQty,
            'item_unit_price': cartItem.unitPrice,
            'total_discount_value': freeQty * cartItem.unitPrice,
          });
        }
      }
    }

    return appliedOffers;
  }

  // Add item to cart
  void addItem(Item item, {double quantity = 1, int? locationId}) async {
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
        discountType: 1, // Fixed (changed from 0=Percentage to 1=Fixed)
        discountLimit: item.discountLimit,
        stockLocationId: itemLocationId, // Use selected location
        availableStock: item.quantity, // Store available stock for display
      );
      _cartItems.add(saleItem);
    }

    notifyListeners();

    // Check for quantity offers after adding/updating item
    await checkAndApplyQuantityOffer(item.itemId);

    // Check for one-time discounts if customer is selected
    if (_selectedCustomer != null) {
      await checkAndApplyOneTimeDiscount(item.itemId);
    }
  }

  // Add SaleItem directly to cart (used for resuming suspended sales)
  void addSaleItem(SaleItem item) {
    final saleItem = item.copyWith(line: _cartItems.length + 1);
    _cartItems.add(saleItem);
    notifyListeners();
  }

  // Update item quantity
  void updateQuantity(int index, double quantity) async {
    if (index >= 0 && index < _cartItems.length) {
      if (quantity <= 0) {
        removeItem(index);
      } else {
        final itemId = _cartItems[index].itemId;
        _cartItems[index] = _cartItems[index].copyWith(quantity: quantity);
        notifyListeners();

        // Check for quantity offers after updating quantity
        await checkAndApplyQuantityOffer(itemId);

        // Check for one-time discounts if customer is selected
        if (_selectedCustomer != null) {
          await checkAndApplyOneTimeDiscount(itemId);
        }
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
  void updateDiscount(int index, double discount, {int discountType = 1}) {
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
      final itemId = _cartItems[index].itemId;
      _cartItems.removeAt(index);
      // Remove associated one-time discount and quantity offer
      _oneTimeDiscounts.remove(itemId);
      _quantityOffers.remove(itemId);
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
    _oneTimeDiscounts.clear();
    _quantityOffers.clear();
    notifyListeners();
  }

  // Check and apply one-time discount for an item
  Future<bool> checkAndApplyOneTimeDiscount(int itemId, {String? date}) async {
    // Must have customer and stock location
    if (_selectedCustomer == null || _stockLocation == null) {
      debugPrint('OneTimeDiscount: Skipped - customer=${_selectedCustomer?.personId}, location=$_stockLocation');
      return false;
    }

    try {
      debugPrint('OneTimeDiscount: Checking item=$itemId, customer=${_selectedCustomer!.personId}, location=$_stockLocation');
      final response = await _apiService.checkOneTimeDiscount(
        customerId: _selectedCustomer!.personId,
        itemId: itemId,
        locationId: _stockLocation!,
        date: date,
      );

      debugPrint('OneTimeDiscount: API response success=${response.isSuccess}, available=${response.data?.available}');

      if (response.isSuccess && response.data != null && response.data!.available) {
        final discount = response.data!.discount;
        if (discount != null) {
          debugPrint('OneTimeDiscount: Found discount amount=${discount.discountAmount}, requiredQty=${discount.quantity}');
          // Store the discount info (for reference even if not yet applicable)
          _oneTimeDiscounts[itemId] = discount;

          // Find the item in cart
          final index = _cartItems.indexWhere((item) => item.itemId == itemId);
          if (index >= 0) {
            final item = _cartItems[index];
            debugPrint('OneTimeDiscount: Cart item qty=${item.quantity}, required=${discount.quantity}');

            // Only apply discount if quantity meets the required threshold
            if (discount.isValidForQuantity(item.quantity)) {
              // Calculate total discount for the quantity
              final totalDiscount = discount.getTotalDiscountAmount(item.quantity);
              debugPrint('OneTimeDiscount: Applying totalDiscount=$totalDiscount');

              // Apply as fixed discount
              _cartItems[index] = item.copyWith(
                discount: totalDiscount,
                discountType: 1, // Fixed
              );
              notifyListeners();
              return true;
            } else {
              debugPrint('OneTimeDiscount: Quantity not met - cart=${item.quantity}, required=${discount.quantity}');
              // Quantity not sufficient - clear any existing discount
              if (item.discount > 0) {
                _cartItems[index] = item.copyWith(
                  discount: 0.0,
                  discountType: 1, // Fixed
                );
                notifyListeners();
              }
              return false;
            }
          }
        }
      } else {
        debugPrint('OneTimeDiscount: No discount available - ${response.message}');
      }
      return false;
    } catch (e) {
      debugPrint('OneTimeDiscount: Error - $e');
      return false;
    }
  }

  // Check for one-time discounts for all items in cart
  Future<void> checkAllOneTimeDiscounts({String? date}) async {
    if (_selectedCustomer == null || _stockLocation == null) {
      return;
    }

    for (var item in _cartItems) {
      await checkAndApplyOneTimeDiscount(item.itemId, date: date);
    }
  }

  // Mark all used one-time discounts (call after sale completion)
  Future<void> markDiscountsAsUsed(int saleId) async {
    final discountIds = getAppliedDiscountIds();
    debugPrint('markDiscountsAsUsed: sale_id=$saleId, discountIds=$discountIds');

    for (var discountId in discountIds) {
      try {
        debugPrint('markDiscountsAsUsed: Calling API for discount_id=$discountId');
        final response = await _apiService.useOneTimeDiscount(
          discountId: discountId,
          saleId: saleId,
        );
        debugPrint('markDiscountsAsUsed: API response success=${response.isSuccess}, message=${response.message}');
      } catch (e) {
        debugPrint('markDiscountsAsUsed: Error marking discount $discountId as used: $e');
      }
    }
  }

  // Check and apply quantity offer for an item
  Future<bool> checkAndApplyQuantityOffer(int itemId, {String? date}) async {
    // Must have stock location
    if (_stockLocation == null) {
      return false;
    }

    try {
      final response = await _apiService.checkQuantityOffer(
        itemId: itemId,
        locationId: _stockLocation!,
        customerId: _selectedCustomer?.personId,
        date: date,
      );

      if (response.isSuccess && response.data != null && response.data!.available) {
        final offer = response.data!.offer;
        if (offer != null) {
          // Store the offer info
          _quantityOffers[itemId] = offer;

          // Notify listeners to update UI
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking quantity offer: $e');
      return false;
    }
  }

  // Check for quantity offers for all items in cart
  Future<void> checkAllQuantityOffers({String? date}) async {
    if (_stockLocation == null) {
      return;
    }

    for (var item in _cartItems) {
      await checkAndApplyQuantityOffer(item.itemId, date: date);
    }
  }

  // Mark all quantity offers as redeemed (call after sale completion)
  Future<void> markOffersAsRedeemed(int saleId) async {
    final appliedOffers = getAppliedOffers();

    for (var offerData in appliedOffers) {
      try {
        await _apiService.redeemOffer(
          offerId: offerData['offer_id'],
          saleId: saleId,
          itemId: offerData['item_id'],
          locationId: _stockLocation!,
          customerId: _selectedCustomer?.personId,
          purchasedQuantity: offerData['purchased_quantity'],
          rewardQuantity: offerData['reward_quantity'],
          itemUnitPrice: offerData['item_unit_price'],
          totalDiscountValue: offerData['total_discount_value'],
        );
      } catch (e) {
        debugPrint('Error redeeming offer ${offerData['offer_id']}: $e');
      }
    }
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

  // Apply fixed discount to entire cart
  void applyCartDiscount(double discountAmount) {
    for (int i = 0; i < _cartItems.length; i++) {
      _cartItems[i] = _cartItems[i].copyWith(
        discount: discountAmount,
        discountType: 1, // Fixed
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

  /// Submit sale - handles both online and offline scenarios
  /// Returns a SaleSubmitResult with sale info and offline status
  Future<SaleSubmitResult> submitSale({
    required OfflineProvider offlineProvider,
    required int employeeId,
    String? comment,
    int saleType = 0,
  }) async {
    // Create sale
    final sale = Sale(
      saleTime: DateTime.now().toIso8601String(),
      customerId: _selectedCustomer?.personId,
      employeeId: employeeId,
      comment: comment,
      saleStatus: 0,
      saleType: saleType,
      subtotal: subtotal,
      taxTotal: 0,
      total: total,
      items: _cartItems,
      payments: _payments,
    );

    // Check if online
    if (offlineProvider.isOnline) {
      // Online - submit to API
      try {
        final response = await _apiService.createSale(sale);
        if (response.isSuccess && response.data != null) {
          return SaleSubmitResult(
            success: true,
            isOffline: false,
            saleId: response.data!.saleId,
            message: 'Sale completed successfully',
          );
        } else {
          // API failed, try to save offline
          return await _saveOfflineSale(sale, offlineProvider, employeeId);
        }
      } catch (e) {
        // Network error, save offline
        debugPrint('SaleProvider: Online sale failed, saving offline - $e');
        return await _saveOfflineSale(sale, offlineProvider, employeeId);
      }
    } else {
      // Offline - save locally
      return await _saveOfflineSale(sale, offlineProvider, employeeId);
    }
  }

  /// Save sale to local database when offline
  Future<SaleSubmitResult> _saveOfflineSale(
    Sale sale,
    OfflineProvider offlineProvider,
    int employeeId,
  ) async {
    final database = offlineProvider.database;
    if (database == null) {
      return SaleSubmitResult(
        success: false,
        isOffline: true,
        message: 'Offline database not initialized',
      );
    }

    try {
      // Create sale data map
      final saleData = {
        'customer_id': _selectedCustomer?.personId,
        'employee_id': employeeId,
        'sale_type': sale.saleType,
        'sale_status': 0,
        'sale_time': sale.saleTime,
        'stock_location_id': _stockLocation,
        'comment': sale.comment,
        'subtotal': subtotal,
        'tax_total': 0,
        'total': total,
        'amount_tendered': _payments.fold<double>(0, (sum, p) => sum + p.amount),
        'amount_change': 0,
      };

      // Convert sale items to local format
      final items = _cartItems.map((item) {
        return {
          'item_id': item.itemId,
          'item_name': item.itemName,
          'item_cost_price': item.costPrice,
          'item_unit_price': item.unitPrice,
          'quantity_purchased': item.quantity,
          'discount': item.discount,
          'discount_type': item.discountType,
          'discount_limit': item.discountLimit,
          'item_location': item.stockLocationId ?? _stockLocation,
          'serialnumber': item.serialNumber,
          'one_time_discount_id': _oneTimeDiscounts[item.itemId]?.discountId,
          'quantity_offer_id': item.quantityOfferId,
          'quantity_offer_free': item.quantityOfferFree ? 1 : 0,
          'parent_line': item.parentLine,
        };
      }).toList();

      // Convert payments to local format
      final payments = _payments.map((payment) {
        return {
          'payment_type': payment.paymentType,
          'payment_amount': payment.amount,
        };
      }).toList();

      // Create local sale with all details
      final localSaleId = await database.createLocalSale(saleData, items, payments);

      // Mark one-time discounts as used locally
      for (final discountId in getAppliedDiscountIds()) {
        await database.markOneTimeDiscountUsed(discountId, localSaleId);
      }

      return SaleSubmitResult(
        success: true,
        isOffline: true,
        localSaleId: localSaleId,
        message: 'Sale saved offline. Will sync when online.',
      );
    } catch (e) {
      debugPrint('SaleProvider: Failed to save offline sale - $e');
      return SaleSubmitResult(
        success: false,
        isOffline: true,
        message: 'Failed to save sale offline: $e',
      );
    }
  }

  /// Mark discounts as used locally (for offline sales)
  Future<void> markDiscountsAsUsedLocally(int localSaleId, OfflineProvider offlineProvider) async {
    final database = offlineProvider.database;
    if (database == null) return;

    for (final discountId in getAppliedDiscountIds()) {
      try {
        await database.markOneTimeDiscountUsed(discountId, localSaleId);
        debugPrint('SaleProvider: Marked discount $discountId as used locally');
      } catch (e) {
        debugPrint('SaleProvider: Failed to mark discount as used locally - $e');
      }
    }
  }
}

/// Result of a sale submission (online or offline)
class SaleSubmitResult {
  final bool success;
  final bool isOffline;
  final int? saleId;
  final int? localSaleId;
  final String message;

  SaleSubmitResult({
    required this.success,
    required this.isOffline,
    this.saleId,
    this.localSaleId,
    required this.message,
  });

  /// Get display sale ID (server or local)
  int? get displaySaleId => saleId ?? localSaleId;
}
