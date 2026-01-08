import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/public_product.dart';
import '../models/public_order.dart';
import '../config/clients_config.dart';

/// API Service for public-facing landing page endpoints (no authentication required)
class PublicApiService {
  static const String _deviceIdKey = 'landing_device_id';

  // Get base URL for public API
  static String get baseUrl {
    final client = ClientsConfig.getDefaultClient();
    if (kReleaseMode) {
      return client.prodApiUrl.replaceAll('/api', '/api/public');
    } else {
      return client.devApiUrl.replaceAll('/api', '/api/public');
    }
  }

  // Get uploads base URL
  static String get uploadsBaseUrl {
    final client = ClientsConfig.getDefaultClient();
    String apiUrl;
    if (kReleaseMode) {
      apiUrl = client.prodApiUrl;
    } else {
      apiUrl = client.devApiUrl;
    }
    // Remove /api from the end and add /uploads
    if (apiUrl.endsWith('/api')) {
      return apiUrl.replaceAll('/api', '/uploads');
    }
    return '$apiUrl/uploads';
  }

  /// Get product image URL
  static String getProductImageUrl(String? filename) {
    if (filename == null || filename.isEmpty) {
      return '';
    }
    final url = '$uploadsBaseUrl/products/$filename';
    debugPrint('📷 Product Image URL: $url');
    return url;
  }

  /// Get portfolio image URL
  static String getPortfolioImageUrl(String? filename) {
    if (filename == null || filename.isEmpty) {
      return '';
    }
    final url = '$uploadsBaseUrl/portfolio/$filename';
    debugPrint('📷 Portfolio Image URL: $url');
    return url;
  }

  /// Get or generate device ID for like tracking
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // Generate a unique device ID
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode}';
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  /// Get headers with device ID
  Future<Map<String, String>> _getHeaders({bool includeDeviceId = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeDeviceId) {
      headers['X-Device-ID'] = await getDeviceId();
    }

    return headers;
  }

  // ========================================
  // PRODUCTS
  // ========================================

  /// Get products list with pagination and filters
  Future<ProductsResponse> getProducts({
    String? search,
    String? category,
    int limit = 20,
    int offset = 0,
    String sort = 'latest', // latest, popular, price_low, price_high, name
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort': sort,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }

      final uri = Uri.parse('$baseUrl/products').replace(queryParameters: queryParams);
      final headers = await _getHeaders();

      final response = await http.get(uri, headers: headers);
      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        final productsData = data['data'];
        return ProductsResponse(
          products: (productsData['products'] as List)
              .map((e) => PublicProduct.fromJson(e))
              .toList(),
          total: productsData['total'] ?? 0,
          limit: productsData['limit'] ?? limit,
          offset: productsData['offset'] ?? offset,
        );
      } else {
        throw Exception(data['message'] ?? 'Failed to load products');
      }
    } catch (e) {
      debugPrint('Error getting products: $e');
      rethrow;
    }
  }

  /// Get single product details
  Future<PublicProduct> getProduct(int itemId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/products/$itemId'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        return PublicProduct.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Product not found');
      }
    } catch (e) {
      debugPrint('Error getting product: $e');
      rethrow;
    }
  }

  /// Get all categories
  Future<List<ProductCategory>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: await _getHeaders(includeDeviceId: false),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        return (data['data'] as List)
            .map((e) => ProductCategory.fromJson(e))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to load categories');
      }
    } catch (e) {
      debugPrint('Error getting categories: $e');
      rethrow;
    }
  }

  // ========================================
  // LIKES
  // ========================================

  /// Like or unlike a product
  Future<LikeResponse> toggleLike(int itemId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/products/$itemId/like'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        return LikeResponse(
          liked: data['data']['liked'] ?? false,
          likesCount: data['data']['likes_count'] ?? 0,
        );
      } else {
        throw Exception(data['message'] ?? 'Failed to toggle like');
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      rethrow;
    }
  }

  // ========================================
  // ORDERS
  // ========================================

  /// Place a new order
  Future<PublicOrder> createOrder({
    required String name,
    required String phone,
    String? email,
    String? address,
    required List<CartItem> items,
    String? notes,
  }) async {
    try {
      final body = {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        'items': items.map((e) => e.toOrderJson()).toList(),
        if (notes != null) 'notes': notes,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: await _getHeaders(includeDeviceId: false),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        return PublicOrder.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  /// Get order history by phone number
  Future<OrdersResponse> getOrderHistory({
    required String phone,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final body = {
        'phone': phone,
        'limit': limit,
        'offset': offset,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/orders/history'),
        headers: await _getHeaders(includeDeviceId: false),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        final ordersData = data['data'];
        return OrdersResponse(
          orders: (ordersData['orders'] as List)
              .map((e) => PublicOrder.fromJson(e))
              .toList(),
          total: ordersData['total'] ?? 0,
          limit: ordersData['limit'] ?? limit,
          offset: ordersData['offset'] ?? offset,
        );
      } else {
        throw Exception(data['message'] ?? 'Failed to load order history');
      }
    } catch (e) {
      debugPrint('Error getting order history: $e');
      rethrow;
    }
  }

  /// Get single order by order number
  Future<PublicOrder> getOrder(String orderNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/$orderNumber'),
        headers: await _getHeaders(includeDeviceId: false),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        return PublicOrder.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Order not found');
      }
    } catch (e) {
      debugPrint('Error getting order: $e');
      rethrow;
    }
  }

  // ========================================
  // BUSINESS INFO
  // ========================================

  /// Get business information
  Future<BusinessInfo> getBusinessInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/business-info'),
        headers: await _getHeaders(includeDeviceId: false),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        return BusinessInfo.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to load business info');
      }
    } catch (e) {
      debugPrint('Error getting business info: $e');
      rethrow;
    }
  }
}

// ========================================
// Response Models
// ========================================

class ProductsResponse {
  final List<PublicProduct> products;
  final int total;
  final int limit;
  final int offset;

  ProductsResponse({
    required this.products,
    required this.total,
    required this.limit,
    required this.offset,
  });

  bool get hasMore => offset + products.length < total;
}

class OrdersResponse {
  final List<PublicOrder> orders;
  final int total;
  final int limit;
  final int offset;

  OrdersResponse({
    required this.orders,
    required this.total,
    required this.limit,
    required this.offset,
  });

  bool get hasMore => offset + orders.length < total;
}

class LikeResponse {
  final bool liked;
  final int likesCount;

  LikeResponse({
    required this.liked,
    required this.likesCount,
  });
}
