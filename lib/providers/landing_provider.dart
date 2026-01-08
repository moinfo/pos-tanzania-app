import 'package:flutter/foundation.dart';
import '../models/public_product.dart';
import '../models/public_order.dart';
import '../services/public_api_service.dart';

/// Provider for landing page state management
class LandingProvider with ChangeNotifier {
  final PublicApiService _apiService = PublicApiService();

  // State
  List<PublicProduct> _products = [];
  List<ProductCategory> _categories = [];
  BusinessInfo? _businessInfo;
  List<CartItem> _cart = [];
  List<PublicOrder> _orderHistory = [];

  // Loading states
  bool _isLoadingProducts = false;
  bool _isLoadingCategories = false;
  bool _isLoadingBusinessInfo = false;
  bool _isLoadingOrders = false;
  bool _isPlacingOrder = false;

  // Pagination
  int _totalProducts = 0;
  int _currentOffset = 0;
  static const int _pageSize = 20;
  bool _hasMoreProducts = true;

  // Filters
  String? _selectedCategory;
  String? _searchQuery;
  String _sortBy = 'latest';

  // Error handling
  String? _error;

  // Cache state
  bool _isFromCache = false;

  // Getters
  List<PublicProduct> get products => _products;
  List<ProductCategory> get categories => _categories;
  BusinessInfo? get businessInfo => _businessInfo;
  List<CartItem> get cart => _cart;
  List<PublicOrder> get orderHistory => _orderHistory;

  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingCategories => _isLoadingCategories;
  bool get isLoadingBusinessInfo => _isLoadingBusinessInfo;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isPlacingOrder => _isPlacingOrder;

  int get totalProducts => _totalProducts;
  bool get hasMoreProducts => _hasMoreProducts;

  String? get selectedCategory => _selectedCategory;
  String? get searchQuery => _searchQuery;
  String get sortBy => _sortBy;

  String? get error => _error;
  String get errorMessage => _error ?? '';
  bool get isFromCache => _isFromCache;

  // Cart getters
  int get cartItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal => _cart.fold(0, (sum, item) => sum + item.subtotal);
  bool get isCartEmpty => _cart.isEmpty;

  // ========================================
  // INITIALIZATION
  // ========================================

  /// Initialize landing page data
  Future<void> initialize() async {
    await Future.wait([
      loadProducts(refresh: true),
      loadCategories(),
      loadBusinessInfo(),
    ]);
  }

  // ========================================
  // PRODUCTS
  // ========================================

  /// Load products with optional refresh
  Future<void> loadProducts({bool refresh = false}) async {
    if (_isLoadingProducts) return;

    if (refresh) {
      _currentOffset = 0;
      _products = [];
      _hasMoreProducts = true;
    }

    if (!_hasMoreProducts) return;

    _isLoadingProducts = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getProducts(
        search: _searchQuery,
        category: _selectedCategory,
        limit: _pageSize,
        offset: _currentOffset,
        sort: _sortBy,
      );

      if (refresh) {
        _products = response.products;
      } else {
        _products.addAll(response.products);
      }

      _totalProducts = response.total;
      _currentOffset += response.products.length;
      _hasMoreProducts = response.hasMore;
      _isFromCache = response.fromCache;
    } catch (e) {
      _error = 'Unable to load products. Check your internet connection.';
      debugPrint('Error loading products: $e');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Load more products (pagination)
  Future<void> loadMoreProducts() async {
    if (!_hasMoreProducts || _isLoadingProducts) return;
    await loadProducts();
  }

  /// Search products
  Future<void> searchProducts(String query) async {
    _searchQuery = query.isEmpty ? null : query;
    await loadProducts(refresh: true);
  }

  /// Filter by category
  Future<void> filterByCategory(String? category) async {
    _selectedCategory = category;
    await loadProducts(refresh: true);
  }

  /// Change sort order
  Future<void> changeSortOrder(String sort) async {
    _sortBy = sort;
    await loadProducts(refresh: true);
  }

  /// Clear all filters
  Future<void> clearFilters() async {
    _searchQuery = null;
    _selectedCategory = null;
    _sortBy = 'latest';
    await loadProducts(refresh: true);
  }

  // ========================================
  // CATEGORIES
  // ========================================

  /// Load categories
  Future<void> loadCategories() async {
    if (_isLoadingCategories) return;

    _isLoadingCategories = true;
    notifyListeners();

    try {
      _categories = await _apiService.getCategories();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  // ========================================
  // BUSINESS INFO
  // ========================================

  /// Load business info
  Future<void> loadBusinessInfo() async {
    if (_isLoadingBusinessInfo) return;

    _isLoadingBusinessInfo = true;
    notifyListeners();

    try {
      _businessInfo = await _apiService.getBusinessInfo();
    } catch (e) {
      debugPrint('Error loading business info: $e');
    } finally {
      _isLoadingBusinessInfo = false;
      notifyListeners();
    }
  }

  // ========================================
  // LIKES
  // ========================================

  /// Toggle like on a product
  Future<void> toggleLike(int itemId) async {
    try {
      final response = await _apiService.toggleLike(itemId);

      // Update product in list
      final index = _products.indexWhere((p) => p.itemId == itemId);
      if (index != -1) {
        _products[index] = _products[index].copyWith(
          isLiked: response.liked,
          likesCount: response.likesCount,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  // ========================================
  // CART
  // ========================================

  /// Add item to cart
  void addToCart(PublicProduct product, {int quantity = 1, String priceType = 'retail'}) {
    final existingIndex = _cart.indexWhere((item) => item.itemId == product.itemId);

    if (existingIndex != -1) {
      _cart[existingIndex].quantity += quantity;
    } else {
      _cart.add(CartItem(
        itemId: product.itemId,
        itemName: product.name,
        image: product.displayImage,
        retailPrice: product.retailPrice,
        wholesalePrice: product.wholesalePrice,
        quantity: quantity,
        priceType: priceType,
      ));
    }

    notifyListeners();
  }

  /// Update cart item quantity
  void updateCartQuantity(int itemId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(itemId);
      return;
    }

    final index = _cart.indexWhere((item) => item.itemId == itemId);
    if (index != -1) {
      _cart[index].quantity = quantity;
      notifyListeners();
    }
  }

  /// Update cart item price type
  void updateCartPriceType(int itemId, String priceType) {
    final index = _cart.indexWhere((item) => item.itemId == itemId);
    if (index != -1) {
      _cart[index].priceType = priceType;
      notifyListeners();
    }
  }

  /// Remove item from cart
  void removeFromCart(int itemId) {
    _cart.removeWhere((item) => item.itemId == itemId);
    notifyListeners();
  }

  /// Clear cart
  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Check if item is in cart
  bool isInCart(int itemId) {
    return _cart.any((item) => item.itemId == itemId);
  }

  /// Get cart item by ID
  CartItem? getCartItem(int itemId) {
    try {
      return _cart.firstWhere((item) => item.itemId == itemId);
    } catch (e) {
      return null;
    }
  }

  // ========================================
  // ORDERS
  // ========================================

  /// Place order
  Future<PublicOrder?> placeOrder({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    if (_cart.isEmpty) {
      _error = 'Cart is empty';
      notifyListeners();
      return null;
    }

    _isPlacingOrder = true;
    _error = null;
    notifyListeners();

    try {
      final order = await _apiService.createOrder(
        name: name,
        phone: phone,
        email: email,
        address: address,
        items: _cart,
        notes: notes,
      );

      // Clear cart after successful order
      _cart.clear();

      // Add to order history
      _orderHistory.insert(0, order);

      notifyListeners();
      return order;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error placing order: $e');
      notifyListeners();
      return null;
    } finally {
      _isPlacingOrder = false;
      notifyListeners();
    }
  }

  /// Load order history by phone
  Future<void> loadOrderHistory(String phone) async {
    if (_isLoadingOrders) return;

    _isLoadingOrders = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getOrderHistory(phone: phone);
      _orderHistory = response.orders;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading order history: $e');
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  /// Clear order history
  void clearOrderHistory() {
    _orderHistory.clear();
    notifyListeners();
  }

  // ========================================
  // ERROR HANDLING
  // ========================================

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
