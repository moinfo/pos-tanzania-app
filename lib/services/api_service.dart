import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response.dart';
import '../models/user.dart';
import '../models/zreport.dart';
import '../models/cash_submit.dart';
import '../models/supervisor.dart';
import '../models/banking.dart';
import '../models/profit_submit.dart';
import '../models/contract.dart';
import '../models/expense.dart';
import '../models/customer.dart';
import '../models/item.dart';
import '../models/credit.dart' hide SaleItem; // Hide SaleItem from credit to avoid conflict
import '../models/supplier.dart';
import '../models/receiving.dart';
import '../models/sale.dart'; // Use SaleItem from sale.dart
import '../models/stock_location.dart';
import '../models/client_config.dart';
import '../models/transaction.dart';
import '../models/report.dart';
import '../models/stock_tracking.dart';
import '../models/position.dart';
import '../models/suspended_sheet.dart';
import '../models/suspended_sheet2.dart';
import '../models/suspended_sheet3.dart';
import '../models/customer_care.dart';
import '../models/map_route.dart';
import '../models/suspended_summary.dart';
import '../models/item_comment.dart';
import '../models/one_time_discount.dart';
import '../models/item_quantity_offer.dart';
import '../models/customer_card.dart';
import '../models/nfc_wallet.dart';
import '../config/clients_config.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  String? _token;

  // Make currentClient public so it can be accessed from main_navigation
  static ClientConfig? currentClient;

  // In-memory cache for dashboard data (with 60 second TTL)
  static Map<String, dynamic>? _dashboardCache;
  static DateTime? _dashboardCacheTime;
  static const int _cacheTTLSeconds = 60; // Cache for 60 seconds

  // Get current client configuration
  static Future<ClientConfig> getCurrentClient() async {
    // In RELEASE mode: Use getDefaultClient() which checks FLAVOR first, then falls back to PRODUCTION_CLIENT_ID
    if (kReleaseMode) {
      currentClient = ClientsConfig.getDefaultClient();
      print('🏭 RELEASE MODE: Using client: ${currentClient?.displayName} (${currentClient?.id})');
      print('🏭 Build flavor: "${ClientsConfig.buildFlavor}" | Is flavored: ${ClientsConfig.isFlavoredBuild}');
      return currentClient!;
    }

    // In DEBUG mode: Use SharedPreferences if available
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('selected_client_id');

    print('🔄 DEBUG MODE: Loading client from preferences: $clientId');

    if (clientId != null) {
      currentClient = ClientsConfig.getClientById(clientId);
      print('✅ Loaded client: ${currentClient?.displayName} (${currentClient?.id})');
    } else {
      currentClient = ClientsConfig.getDefaultClient();
      print('⚠️ No saved client, using default: ${currentClient?.displayName}');
    }

    return currentClient!;
  }

  // Set current client
  static Future<void> setCurrentClient(String clientId) async {
    print('💾 Setting client to: $clientId');
    currentClient = ClientsConfig.getClientById(clientId);
    print('💾 Client object: ${currentClient?.displayName}');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_client_id', clientId);
    print('💾 Saved to SharedPreferences: $clientId');

    // Verify it was saved
    final saved = prefs.getString('selected_client_id');
    print('💾 Verification read: $saved');
  }

  // Clear current client (for switching clients)
  static Future<void> clearCurrentClient() async {
    print('🗑️ Clearing current client');
    currentClient = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_client_id');
    print('🗑️ Client cleared from cache and preferences');
  }

  // Get base URL based on current client and build mode
  static Future<String> get baseUrl async {
    final client = await getCurrentClient();
    if (kReleaseMode) {
      return client.prodApiUrl;
    } else {
      return client.devApiUrl;
    }
  }

  // Synchronous version for backwards compatibility (uses cached client)
  static String get baseUrlSync {
    // If no client is cached, load it synchronously
    if (currentClient == null) {
      // Try to load from SharedPreferences synchronously
      // This is a fallback - getCurrentClient should be called during app init
      return ClientsConfig.getDefaultClient().devApiUrl;
    }

    print('📍 Current Client: ${currentClient!.displayName} (${currentClient!.id})');

    if (kReleaseMode) {
      return currentClient!.prodApiUrl;
    } else {
      return currentClient!.devApiUrl;
    }
  }

  // Get stored token
  Future<String?> getToken() async {
    if (_token != null) {
      return _token;
    }

    // Read token and client ID from storage
    final storedToken = await _storage.read(key: 'auth_token');
    final storedClientId = await _storage.read(key: 'auth_token_client_id');

    // Validate token belongs to current client
    if (storedToken != null && storedClientId != null) {
      final currentClientId = currentClient?.id ?? 'sada';

      if (storedClientId != currentClientId) {
        print('⚠️ Token client mismatch: stored=$storedClientId, current=$currentClientId');
        print('🗑️ Clearing mismatched token');
        await clearToken();
        return null;
      }

      _token = storedToken;
    }

    return _token;
  }

  // Save token with client ID
  Future<void> saveToken(String token) async {
    final clientId = currentClient?.id ?? 'sada';

    _token = token;
    await _storage.write(key: 'auth_token', value: token);
    await _storage.write(key: 'auth_token_client_id', value: clientId);

    print('💾 Saved token for client: $clientId');
  }

  // Clear token and client ID
  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_token_client_id');
  }

  // Get headers with authentication
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Get headers for multipart requests
  Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Handle unauthorized access - clear token to trigger logout
  void _handleUnauthorized() {
    // Clear token immediately to prevent further API calls
    _token = null;
    // Delete from storage asynchronously (fire and forget)
    _storage.delete(key: 'auth_token');
    debugPrint('401 Unauthorized: Token cleared, user will be logged out');
  }

  // Handle API response
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    final statusCode = response.statusCode;

    try {
      final jsonResponse = json.decode(response.body);

      if (statusCode >= 200 && statusCode < 300) {
        // Success
        return ApiResponse<T>.success(
          data: fromJson != null && jsonResponse['data'] != null
              ? fromJson(jsonResponse['data'])
              : jsonResponse['data'],
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        // Handle 401 Unauthorized - trigger automatic logout
        if (statusCode == 401) {
          _handleUnauthorized();
        }

        // Error
        return ApiResponse<T>.error(
          message: jsonResponse['message'] ?? 'An error occurred',
          statusCode: statusCode,
        );
      }
    } catch (e) {
      // Print first 500 chars of body for debugging
      final bodyPreview = response.body.length > 500
          ? '${response.body.substring(0, 500)}...'
          : response.body;
      print('Failed to parse JSON. Status: $statusCode, Body: $bodyPreview');

      return ApiResponse<T>.error(
        message: 'Failed to parse response: $e',
        statusCode: statusCode,
      );
    }
  }

  // ============ AUTH ENDPOINTS ============

  /// Login user
  Future<ApiResponse<User>> login(String username, String password) async {
    try {
      final loginUrl = '$baseUrlSync/auth/login';
      print('🔐 LOGIN URL: $loginUrl'); // Debug: Show which API URL is being used
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout - please check your internet connection');
        },
      );

      final result = _handleResponse<User>(
        response,
        (data) => User.fromJson(data),
      );

      // Save token if login successful
      if (result.isSuccess && result.data?.token != null) {
        await saveToken(result.data!.token!);
      }

      return result;
    } on SocketException catch (e) {
      return ApiResponse.error(
        message: 'Network error: Unable to connect to server. Please check your internet connection.',
      );
    } on HttpException catch (e) {
      return ApiResponse.error(
        message: 'HTTP error: ${e.message}',
      );
    } on FormatException catch (e) {
      return ApiResponse.error(
        message: 'Invalid response format from server',
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get user permissions
  Future<Map<String, dynamic>> getUserPermissions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/auth/permissions'),
        headers: await _getHeaders(),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching permissions: $e');
      rethrow;
    }
  }

  /// Verify token
  Future<ApiResponse<User>> verifyToken() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/auth/verify'),
        headers: await _getHeaders(),
      );

      return _handleResponse<User>(
        response,
        (data) => User.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Refresh token
  Future<ApiResponse<Map<String, dynamic>>> refreshToken() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/auth/refresh'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data,
      );

      // Update token if refresh successful
      if (result.isSuccess && result.data?['token'] != null) {
        await saveToken(result.data!['token']);
      }

      return result;
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Logout
  /// NOTE: This preserves biometric credentials for convenience
  /// Only clears session data (auth_token, user_permissions)
  Future<ApiResponse<void>> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrlSync/auth/logout'),
        headers: await _getHeaders(),
      );

      // Clear only session data - preserve biometric credentials
      await clearToken();
      // Note: We intentionally do NOT clear:
      // - biometric_enabled
      // - biometric_username
      // - biometric_password
      // These are kept so the user can login with biometrics again

      return ApiResponse.success(message: 'Logged out successfully');
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ Z REPORTS ENDPOINTS ============

  /// Get all Z reports
  Future<ApiResponse<List<ZReportListItem>>> getZReports({
    String? startDate,
    String? endDate,
    int? locationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (locationId != null) 'location_id': locationId.toString(),
      };

      final uri = Uri.parse('$baseUrlSync/zreports').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final reports = (data['z_reports'] as List)
            .map((item) => ZReportListItem.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: reports,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch Z reports',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get single Z report
  Future<ApiResponse<ZReportDetails>> getZReport(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/zreports/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<ZReportDetails>(
        response,
        (data) => ZReportDetails.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create Z report with file
  Future<ApiResponse<ZReportDetails>> createZReport({
    required double turnover,
    required double net,
    required double tax,
    required double turnoverExSr,
    required double total,
    required double totalCharges,
    required String date,
    int? stockLocationId,
    required String picFile, // Base64 encoded file
  }) async {
    try {
      final body = <String, dynamic>{
        'turnover': turnover,
        'net': net,
        'tax': tax,
        'turnover_ex_sr': turnoverExSr,
        'total': total,
        'total_charges': totalCharges,
        'date': date,
        'pic_file': picFile,
      };

      if (stockLocationId != null) {
        body['stock_location_id'] = stockLocationId;
      }

      final response = await http.post(
        Uri.parse('$baseUrlSync/zreports/create'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      return _handleResponse<ZReportDetails>(
        response,
        (data) => ZReportDetails.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update Z report
  Future<ApiResponse<ZReportDetails>> updateZReport({
    required int id,
    required double turnover,
    required double net,
    required double tax,
    required double turnoverExSr,
    required double total,
    required double totalCharges,
    required String date,
    int? stockLocationId,
    String? picFile, // Optional base64 encoded file
  }) async {
    try {
      final body = <String, dynamic>{
        'turnover': turnover,
        'net': net,
        'tax': tax,
        'turnover_ex_sr': turnoverExSr,
        'total': total,
        'total_charges': totalCharges,
        'date': date,
      };

      if (stockLocationId != null) {
        body['stock_location_id'] = stockLocationId;
      }

      if (picFile != null) {
        body['pic_file'] = picFile;
      }

      final response = await http.put(
        Uri.parse('$baseUrlSync/zreports/update/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      return _handleResponse<ZReportDetails>(
        response,
        (data) => ZReportDetails.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete Z report
  Future<ApiResponse<void>> deleteZReport(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrlSync/zreports/delete/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<void>(response, null);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ CASH SUBMIT ENDPOINTS ============

  /// Get all cash submissions
  Future<ApiResponse<List<CashSubmitListItem>>> getCashSubmissions({
    String? startDate,
    String? endDate,
    int? supervisorId,
    int? locationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (supervisorId != null) 'supervisor_id': supervisorId.toString(),
        if (locationId != null) 'location_id': locationId.toString(),
      };

      final uri = Uri.parse('$baseUrlSync/cashsubmit').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final submissions = (data['cash_submissions'] as List)
            .map((item) => CashSubmitListItem.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: submissions,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch cash submissions',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create cash submission
  Future<ApiResponse<CashSubmitDetails>> createCashSubmission({
    required double amount,
    required String date,
    required int supervisorId,
    int? stockLocationId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/cashsubmit/create'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'supervisor_id': supervisorId,
          if (stockLocationId != null) 'stock_location_id': stockLocationId,
        }),
      );

      return _handleResponse<CashSubmitDetails>(
        response,
        (data) => CashSubmitDetails.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update cash submission
  Future<ApiResponse<CashSubmitDetails>> updateCashSubmission(
    int id, {
    required double amount,
    required String date,
    required int supervisorId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrlSync/cashsubmit/$id'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'supervisor_id': supervisorId,
        }),
      );

      return _handleResponse<CashSubmitDetails>(
        response,
        (data) => CashSubmitDetails.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete cash submission
  Future<ApiResponse<void>> deleteCashSubmission(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrlSync/cashsubmit/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(message: 'Cash submission deleted successfully');
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to delete cash submission',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get supervisors list
  Future<ApiResponse<List<Supervisor>>> getSupervisors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/cashsubmit/supervisors'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final supervisors = (data['supervisors'] as List)
            .map((item) => Supervisor.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: supervisors,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch supervisors',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get today's cash submission summary
  Future<ApiResponse<Map<String, dynamic>>> getCashSubmitTodaySummary({
    String? date,
    int? locationId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (date != null) queryParams['date'] = date;
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/cashsubmit/today_summary')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      print('🌐 Calling: $uri');

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body (first 200 chars): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final jsonResponse = json.decode(response.body);
          return ApiResponse.success(
            data: jsonResponse['data'],
            message: jsonResponse['message'],
          );
        } catch (e) {
          print('❌ JSON decode error: $e');
          print('❌ Response body: ${response.body}');
          return ApiResponse.error(message: 'Invalid JSON response: $e');
        }
      } else {
        try {
          final jsonResponse = json.decode(response.body);
          return ApiResponse.error(
            message: jsonResponse['message'] ?? 'Failed to fetch today summary',
            statusCode: response.statusCode,
          );
        } catch (e) {
          return ApiResponse.error(
            message: 'Server error (${response.statusCode}): ${response.body.substring(0, 100)}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      print('❌ Connection error: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get sellers report (Leruma-specific)
  Future<ApiResponse<Map<String, dynamic>>> getSellersReport({
    String? startDate,
    String? endDate,
    int? supervisorId,
    int? locationId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (supervisorId != null) queryParams['supervisor_id'] = supervisorId.toString();
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/cashsubmit/sellers_report')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          data: jsonResponse['data'],
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch sellers report',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ CONTRACTS ENDPOINTS ============

  /// Get all contracts
  Future<ApiResponse<List<Contract>>> getContracts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/contracts'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final contracts = (data['contracts'] as List)
            .map((item) => Contract.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: contracts,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch contracts',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get single contract
  Future<ApiResponse<Contract>> getContract(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/contracts/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Contract>(
        response,
        (data) => Contract.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get contract statement
  Future<ApiResponse<Map<String, dynamic>>> getContractStatement(
    int contractId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      };

      final uri = Uri.parse('$baseUrlSync/contracts/$contractId/statement').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          data: jsonResponse['data'],
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch contract statement',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ EXPENSES ENDPOINTS ============

  /// Get all expenses
  Future<ApiResponse<List<Expense>>> getExpenses({
    String? startDate,
    String? endDate,
    int? categoryId,
    String? paymentType,
    int? supervisorId,
    int? locationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (categoryId != null) 'category_id': categoryId.toString(),
        if (paymentType != null) 'payment_type': paymentType,
        if (supervisorId != null) 'supervisor_id': supervisorId.toString(),
        if (locationId != null) 'location_id': locationId.toString(),
      };

      final uri = Uri.parse('$baseUrlSync/expenses').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final expenses = (data['expenses'] as List)
            .map((item) => Expense.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: expenses,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch expenses',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get single expense
  Future<ApiResponse<Expense>> getExpense(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/expenses/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Expense>(
        response,
        (data) => Expense.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create expense
  Future<ApiResponse<Expense>> createExpense(ExpenseFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/expenses/create'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Expense>(
        response,
        (data) => Expense.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update expense
  Future<ApiResponse<Expense>> updateExpense(int id, ExpenseFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/expenses/update/$id'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Expense>(
        response,
        (data) => Expense.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete expense
  Future<ApiResponse<void>> deleteExpense(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/expenses/delete/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<void>(response, null);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get expense categories
  Future<ApiResponse<List<ExpenseCategory>>> getExpenseCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/expenses/categories'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final categories = (data['categories'] as List)
            .map((item) => ExpenseCategory.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: categories,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch expense categories',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ CUSTOMERS ENDPOINTS ============

  /// Get all customers
  Future<ApiResponse<List<Customer>>> getCustomers({
    String? search,
    String? supervisorId,
    int? locationId,
    bool? isBodaBoda,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (search != null) 'search': search,
        if (supervisorId != null) 'supervisor_id': supervisorId,
        if (locationId != null) 'location_id': locationId.toString(),
        if (isBodaBoda == true) 'is_boda_boda': '1',
      };

      final uri = Uri.parse('$baseUrlSync/customers').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final customers = (data['customers'] as List)
            .map((item) => Customer.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: customers,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch customers',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get single customer
  Future<ApiResponse<Customer>> getCustomer(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/customers/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Customer>(
        response,
        (data) => Customer.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create customer
  Future<ApiResponse<Customer>> createCustomer(CustomerFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/customers/create'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Customer>(
        response,
        (data) => Customer.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update customer
  Future<ApiResponse<Customer>> updateCustomer(int id, CustomerFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/customers/update/$id'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Customer>(
        response,
        (data) => Customer.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete customer
  Future<ApiResponse<void>> deleteCustomer(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/customers/delete/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<void>(response, null);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============ ITEMS ENDPOINTS ============

  /// Get all items
  Future<ApiResponse<List<Item>>> getItems({
    String? search,
    String? category,
    int limit = 50,
    int offset = 0,
    int? locationId,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (search != null) 'search': search,
        if (category != null) 'category': category,
        if (locationId != null) 'location_id': locationId.toString(),
      };

      final uri = Uri.parse('$baseUrlSync/items').replace(
        queryParameters: queryParams,
      );

      print('🔗 Items API URL: $uri');
      final response = await http.get(uri, headers: await _getHeaders());
      print('📥 Items API status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final items = (data['items'] as List)
            .map((item) => Item.fromJson(item))
            .toList();
        print('✅ Items parsed: ${items.length} items found');

        return ApiResponse.success(
          data: items,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch items',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get single item
  Future<ApiResponse<Item>> getItem(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/items/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Item>(
        response,
        (data) => Item.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create item
  Future<ApiResponse<Item>> createItem(ItemFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/items/create'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Item>(
        response,
        (data) => Item.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update item
  Future<ApiResponse<Item>> updateItem(int id, ItemFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/items/update/$id'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Item>(
        response,
        (data) => Item.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete item
  Future<ApiResponse<void>> deleteItem(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/items/delete/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<void>(response, null);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============================================================================
  // CREDIT MANAGEMENT
  // ============================================================================

  /// Get customer credit statement
  Future<ApiResponse<CreditStatement>> getCreditStatement(
    int customerId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/credits/statement/$customerId')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      return _handleResponse<CreditStatement>(
        response,
        (data) => CreditStatement.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get customer balance
  Future<ApiResponse<CreditBalance>> getCreditBalance(int customerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/credits/balance/$customerId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<CreditBalance>(
        response,
        (data) => CreditBalance.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add payment for customer credit
  Future<ApiResponse<Map<String, dynamic>>> addCreditPayment(
      PaymentFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/credits/add_payment'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update payment for customer credit
  Future<ApiResponse<Map<String, dynamic>>> updateCreditPayment(
      int paymentId, Map<String, dynamic> updateData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/credits/update_payment/$paymentId'),
        headers: await _getHeaders(),
        body: json.encode(updateData),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete payment for customer credit
  Future<ApiResponse<Map<String, dynamic>>> deleteCreditPayment(
      int paymentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/credits/delete_payment/$paymentId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get sale details with items for credit statement
  Future<ApiResponse<SaleDetails>> getCreditSaleDetails(int saleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/credits/sale/$saleId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<SaleDetails>(
        response,
        (data) => SaleDetails.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== SUPPLIER CREDITS API ====================

  /// Get all suppliers with balances
  Future<ApiResponse<List<Supplier>>> getSuppliers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/supplier_credits/suppliers'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'] as List;
        final suppliers = data.map((item) => Supplier.fromJson(item)).toList();

        return ApiResponse.success(
          data: suppliers,
          message: jsonResponse['message'] ?? 'Suppliers retrieved successfully',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to load suppliers',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get suppliers filtered by stock location (Leruma-specific feature)
  /// Returns suppliers that belong to the supervisor of the given stock location
  Future<ApiResponse<List<Supplier>>> getSuppliersByLocation(int locationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/suppliers/by_location/$locationId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data']['suppliers'] as List;
        final suppliers = data.map((item) => Supplier.fromJson(item)).toList();

        return ApiResponse.success(
          data: suppliers,
          message: jsonResponse['message'] ?? 'Suppliers retrieved successfully',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to load suppliers',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get supplier credit statement
  Future<ApiResponse<SupplierStatement>> getSupplierStatement(
    int supplierId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await getToken();

      // Build query parameters
      final Map<String, String> queryParams = {};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/supplier_credits/statement/$supplierId')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return _handleResponse<SupplierStatement>(
        response,
        (data) => SupplierStatement.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add supplier payment
  Future<ApiResponse<Map<String, dynamic>>> addSupplierPayment(
    SupplierPaymentFormData formData,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrlSync/supplier_credits/add_payment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(formData.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get supplier balance
  Future<ApiResponse<Map<String, dynamic>>> getSupplierBalance(
    int supplierId,
  ) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrlSync/supplier_credits/balance/$supplierId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update supplier payment
  Future<ApiResponse<Map<String, dynamic>>> updateSupplierPayment(
    int paymentId,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrlSync/supplier_credits/update_payment/$paymentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(paymentData),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete supplier payment
  Future<ApiResponse<Map<String, dynamic>>> deleteSupplierPayment(int paymentId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrlSync/supplier_credits/delete_payment/$paymentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get single supplier
  Future<ApiResponse<Supplier>> getSupplier(int supplierId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/suppliers/show/$supplierId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Supplier>(
        response,
        (data) => Supplier.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create supplier
  Future<ApiResponse<Supplier>> createSupplier(Map<String, dynamic> supplierData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/suppliers/create'),
        headers: await _getHeaders(),
        body: json.encode(supplierData),
      );

      return _handleResponse<Supplier>(
        response,
        (data) => Supplier.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update supplier
  Future<ApiResponse<Supplier>> updateSupplier(int supplierId, Map<String, dynamic> supplierData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/suppliers/update/$supplierId'),
        headers: await _getHeaders(),
        body: json.encode(supplierData),
      );

      return _handleResponse<Supplier>(
        response,
        (data) => Supplier.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete supplier
  Future<ApiResponse<void>> deleteSupplier(int supplierId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/suppliers/delete/$supplierId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<void>(response, (_) => null);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get supervisors for supplier dropdown
  Future<ApiResponse<List<Map<String, dynamic>>>> getSupplierSupervisors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/suppliers/supervisors'),
        headers: await _getHeaders(),
      );

      return _handleResponse<List<Map<String, dynamic>>>(
        response,
        (data) {
          final supervisors = data['supervisors'] as List;
          return supervisors.map((s) => s as Map<String, dynamic>).toList();
        },
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== RECEIVINGS API ====================

  /// Get receivings list with pagination and search
  Future<ApiResponse<Map<String, dynamic>>> getReceivings({
    int limit = 50,
    int offset = 0,
    String? search,
    String? startDate,
    String? endDate,
    int? locationId,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }

      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }

      if (locationId != null) {
        queryParams['location_id'] = locationId.toString();
      }

      final uri = Uri.parse('$baseUrlSync/receivings').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get receiving details
  Future<ApiResponse<ReceivingDetails>> getReceivingDetails(int receivingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/receivings/$receivingId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<ReceivingDetails>(
        response,
        (data) => ReceivingDetails.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create new receiving
  Future<ApiResponse<Map<String, dynamic>>> createReceiving(Receiving receiving) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/receivings/create'),
        headers: await _getHeaders(),
        body: json.encode(receiving.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete receiving
  Future<ApiResponse<Map<String, dynamic>>> deleteReceiving(int receivingId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrlSync/receivings/$receivingId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get receiving summary comparing mainstore sales vs Leruma receivings
  /// Leruma-specific feature
  Future<ApiResponse<Map<String, dynamic>>> getReceivingSummary({
    required int locationId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'location_id': locationId.toString(),
        'start_date': startDate,
        'end_date': endDate,
      };

      final uri = Uri.parse('$baseUrlSync/receivings/summary').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get receiving summary2 - Leruma receivings as primary, compare with mainstore
  /// Leruma-specific feature
  Future<ApiResponse<Map<String, dynamic>>> getReceivingSummary2({
    required int locationId,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'location_id': locationId.toString(),
        'start_date': startDate,
        'end_date': endDate,
      };

      final uri = Uri.parse('$baseUrlSync/receivings/summary2').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== SALES API ====================

  /// Get sales list with filters
  Future<ApiResponse<Map<String, dynamic>>> getSales({
    String? startDate,
    String? endDate,
    int limit = 50,
    int offset = 0,
    int? customerId,
    int? saleType,
    int? locationId,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (customerId != null) queryParams['customer_id'] = customerId.toString();
      if (saleType != null) queryParams['sale_type'] = saleType.toString();
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/sales').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get single sale details
  Future<ApiResponse<Sale>> getSaleDetails(int saleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/sales/$saleId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Sale>(
        response,
        (data) => Sale.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get sale items
  Future<ApiResponse<List<SaleItem>>> getSaleItems(int saleId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/sales/$saleId/items'),
        headers: await _getHeaders(),
      );

      return _handleResponse<List<SaleItem>>(
        response,
        (data) => (data as List).map((item) => SaleItem.fromJson(item)).toList(),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create new sale
  Future<ApiResponse<Sale>> createSale(Sale sale) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/sales/create'),
        headers: await _getHeaders(),
        body: jsonEncode(sale.toCreateJson()),
      );

      return _handleResponse<Sale>(
        response,
        (data) => Sale.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Suspend current sale
  Future<ApiResponse<Map<String, dynamic>>> suspendSale({
    required List<SaleItem> items,
    int? customerId,
    String? comment,
    int saleType = 0,
  }) async {
    try {
      final requestBody = {
        'items': items.map((i) => i.toCreateJson()).toList(),
        if (customerId != null) 'customer_id': customerId,
        if (comment != null) 'comment': comment,
        'sale_type': saleType,
      };

      final response = await http.post(
        Uri.parse('$baseUrlSync/sales/suspend'),
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get suspended sales
  Future<ApiResponse<List<SuspendedSale>>> getSuspendedSales({
    int? locationId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (locationId != null) {
        queryParams['location_id'] = locationId.toString();
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }

      final uri = Uri.parse('$baseUrlSync/sales/suspended').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        // Check if data is a List or wrapped in another structure
        List<dynamic> salesList;
        if (data is List) {
          salesList = data;
        } else if (data is Map && data['sales'] != null) {
          salesList = data['sales'] as List;
        } else {
          salesList = [];
        }

        final suspendedSales = salesList
            .map((s) => SuspendedSale.fromJson(s as Map<String, dynamic>))
            .toList();

        return ApiResponse.success(
          data: suspendedSales,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch suspended sales',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get suspended sales with items for sheet display
  Future<ApiResponse<List<SuspendedSheetSale>>> getSuspendedSheet({
    required int locationId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/sales/suspended_sheet').replace(
        queryParameters: {'location_id': locationId.toString()},
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        List<dynamic> salesList;
        if (data is List) {
          salesList = data;
        } else {
          salesList = [];
        }

        final suspendedSheetSales = salesList
            .map((s) => SuspendedSheetSale.fromJson(s as Map<String, dynamic>))
            .toList();

        return ApiResponse.success(
          data: suspendedSheetSales,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch suspended sheet',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get suspended sales for delivery sheet (sheet2 format - no prices, includes free items)
  Future<ApiResponse<List<SuspendedSheet2Sale>>> getSuspendedSheet2({
    required int locationId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/sales/suspended_sheet2').replace(
        queryParameters: {'location_id': locationId.toString()},
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        List<dynamic> salesList;
        if (data is List) {
          salesList = data;
        } else {
          salesList = [];
        }

        final suspendedSheet2Sales = salesList
            .map((s) => SuspendedSheet2Sale.fromJson(s as Map<String, dynamic>))
            .toList();

        return ApiResponse.success(
          data: suspendedSheet2Sales,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch delivery sheet',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get suspended sales for full receipt sheet (sheet3 format - with prices + free items)
  Future<ApiResponse<List<SuspendedSheet3Sale>>> getSuspendedSheet3({
    required int locationId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/sales/suspended_sheet3').replace(
        queryParameters: {'location_id': locationId.toString()},
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        List<dynamic> salesList;
        if (data is List) {
          salesList = data;
        } else {
          salesList = [];
        }

        final suspendedSheet3Sales = salesList
            .map((s) => SuspendedSheet3Sale.fromJson(s as Map<String, dynamic>))
            .toList();

        return ApiResponse.success(
          data: suspendedSheet3Sales,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch receipt sheet',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get customer care data (CRM view)
  Future<ApiResponse<CustomerCareResponse>> getCustomerCare({
    required int locationId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/customers/care').replace(
        queryParameters: {'location_id': locationId.toString()},
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final customerCareResponse = CustomerCareResponse.fromJson(data);
          return ApiResponse.success(
            data: customerCareResponse,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.success(
            data: CustomerCareResponse(
              customers: [],
              totals: CustomerCareTotals(creditLimit: 0, balance: 0, customerCount: 0),
            ),
            message: jsonResponse['message'] ?? 'Success',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch customer care data',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get map route data (delivery route planning)
  Future<ApiResponse<MapRouteResponse>> getMapRoute({
    required int locationId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/customers/map_route').replace(
        queryParameters: {'location_id': locationId.toString()},
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final mapRouteResponse = MapRouteResponse.fromJson(data);
          return ApiResponse.success(
            data: mapRouteResponse,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.success(
            data: MapRouteResponse(customers: [], customerCount: 0),
            message: jsonResponse['message'] ?? 'Success',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch map route data',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update customer order for route planning
  Future<ApiResponse<void>> updateCustomerOrder({
    required List<Map<String, int>> orders,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/customers/update_order'),
        headers: await _getHeaders(),
        body: json.encode({'orders': orders}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(data: null, message: 'Order updated successfully');
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to update order',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get suspended items summary
  Future<ApiResponse<SuspendedSummaryResponse>> getSuspendedSummary({
    required int locationId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/sales/suspended_summary').replace(
        queryParameters: {'location_id': locationId.toString()},
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final summaryResponse = SuspendedSummaryResponse.fromJson(data);
          return ApiResponse.success(
            data: summaryResponse,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.success(
            data: SuspendedSummaryResponse(
              items: [],
              totals: SuspendedSummaryTotals(
                totalQuantity: 0,
                grandTotal: 0,
                totalWeight: 0,
                itemCount: 0,
              ),
            ),
            message: jsonResponse['message'] ?? 'Success',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch suspended summary',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get item comment and history
  Future<ApiResponse<ItemCommentResponse>> getItemComment({
    required int itemId,
    required int locationId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/item_comments/get').replace(
        queryParameters: {
          'item_id': itemId.toString(),
          'location_id': locationId.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final commentResponse = ItemCommentResponse.fromJson(data);
          return ApiResponse.success(
            data: commentResponse,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.success(
            data: ItemCommentResponse(comment: null, history: []),
            message: jsonResponse['message'] ?? 'Success',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch comment',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Save item comment
  Future<ApiResponse<ItemCommentResponse>> saveItemComment({
    required int itemId,
    required int locationId,
    required String comment,
    required String commentDate,
    int? commentId,
  }) async {
    try {
      final body = {
        'item_id': itemId,
        'location_id': locationId,
        'comment': comment,
        'comment_date': commentDate,
        if (commentId != null) 'comment_id': commentId,
      };

      final response = await http.post(
        Uri.parse('$baseUrlSync/item_comments/save'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final commentResponse = ItemCommentResponse.fromJson(data);
          return ApiResponse.success(
            data: commentResponse,
            message: jsonResponse['message'] ?? 'Comment saved successfully',
          );
        } else {
          return ApiResponse.success(
            data: ItemCommentResponse(comment: null, history: []),
            message: jsonResponse['message'] ?? 'Comment saved',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to save comment',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete item comment
  Future<ApiResponse<List<CommentHistoryItem>>> deleteItemComment({
    required int commentId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/item_comments/delete'),
        headers: await _getHeaders(),
        body: json.encode({'comment_id': commentId}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final history = (data?['history'] as List<dynamic>?)
                ?.map((item) =>
                    CommentHistoryItem.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];

        return ApiResponse.success(
          data: history,
          message: jsonResponse['message'] ?? 'Comment deleted successfully',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to delete comment',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== ONE TIME DISCOUNTS API (Leruma-specific) ====================

  /// Check if one-time discount is available for item/customer/location/date
  Future<ApiResponse<CheckDiscountResponse>> checkOneTimeDiscount({
    required int customerId,
    required int itemId,
    required int locationId,
    String? date,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/one_time_discounts/check').replace(
        queryParameters: {
          'customer_id': customerId.toString(),
          'item_id': itemId.toString(),
          'stock_location_id': locationId.toString(),
          if (date != null) 'date': date,
        },
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final checkResponse = CheckDiscountResponse.fromJson(data);
          return ApiResponse.success(
            data: checkResponse,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.success(
            data: CheckDiscountResponse(available: false, discount: null),
            message: jsonResponse['message'] ?? 'Success',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to check discount',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get one-time discount details by ID
  Future<ApiResponse<OneTimeDiscount>> getOneTimeDiscount(int discountId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/one_time_discounts/$discountId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data['discount'] != null) {
          final discount = OneTimeDiscount.fromJson(data['discount']);
          return ApiResponse.success(
            data: discount,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.error(message: 'Discount not found');
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch discount',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get all active discounts for a customer
  Future<ApiResponse<CustomerDiscountsResponse>> getCustomerDiscounts({
    required int customerId,
    int? locationId,
    String? date,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (locationId != null) {
        queryParams['stock_location_id'] = locationId.toString();
      }
      if (date != null) {
        queryParams['date'] = date;
      }

      final uri = Uri.parse('$baseUrlSync/one_time_discounts/customer/$customerId')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final discountsResponse = CustomerDiscountsResponse.fromJson(data);
          return ApiResponse.success(
            data: discountsResponse,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.success(
            data: CustomerDiscountsResponse(discounts: [], count: 0),
            message: jsonResponse['message'] ?? 'Success',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch discounts',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Mark one-time discount as used
  Future<ApiResponse<void>> useOneTimeDiscount({
    required int discountId,
    required int saleId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/one_time_discounts/mark_used'),
        headers: await _getHeaders(),
        body: json.encode({
          'discount_id': discountId,
          'sale_id': saleId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          data: null,
          message: jsonResponse['message'] ?? 'Discount marked as used',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to use discount',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== ITEM QUANTITY OFFERS API (Leruma-specific) ====================

  /// Check if quantity offer is available for item/customer/location/date
  Future<ApiResponse<CheckOfferResponse>> checkQuantityOffer({
    required int itemId,
    required int locationId,
    int? customerId,
    String? date,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/item_quantity_offers/check').replace(
        queryParameters: {
          'item_id': itemId.toString(),
          'stock_location_id': locationId.toString(),
          if (customerId != null) 'customer_id': customerId.toString(),
          if (date != null) 'date': date,
        },
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final checkResponse = CheckOfferResponse.fromJson(data);
          return ApiResponse.success(
            data: checkResponse,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.success(
            data: CheckOfferResponse(available: false, offer: null),
            message: jsonResponse['message'] ?? 'Success',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to check offer',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Calculate reward quantity for a purchase
  Future<ApiResponse<RewardCalculationResponse>> calculateReward({
    required int offerId,
    required double purchasedQuantity,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/item_quantity_offers/calculate_reward'),
        headers: await _getHeaders(),
        body: json.encode({
          'offer_id': offerId,
          'purchased_quantity': purchasedQuantity,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final calculation = RewardCalculationResponse.fromJson(data);
          return ApiResponse.success(
            data: calculation,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.error(message: 'Invalid response format');
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to calculate reward',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Record offer redemption when sale completes
  Future<ApiResponse<Map<String, dynamic>>> redeemOffer({
    required int offerId,
    required int saleId,
    required int itemId,
    required int locationId,
    int? customerId,
    required double purchasedQuantity,
    required double rewardQuantity,
    int? ratioMultiplier,
    int? tierId,
    required double itemUnitPrice,
    required double totalDiscountValue,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/item_quantity_offers/redeem'),
        headers: await _getHeaders(),
        body: json.encode({
          'offer_id': offerId,
          'sale_id': saleId,
          'item_id': itemId,
          'stock_location_id': locationId,
          if (customerId != null) 'customer_id': customerId,
          'purchased_quantity': purchasedQuantity,
          'reward_quantity': rewardQuantity,
          if (ratioMultiplier != null) 'ratio_multiplier': ratioMultiplier,
          if (tierId != null) 'tier_id': tierId,
          'item_unit_price': itemUnitPrice,
          'total_discount_value': totalDiscountValue,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'] ?? {};
        return ApiResponse.success(
          data: data as Map<String, dynamic>,
          message: jsonResponse['message'] ?? 'Offer redeemed successfully',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to redeem offer',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get all active offers for a customer at a location
  Future<ApiResponse<ActiveOffersResponse>> getActiveOffers({
    required int locationId,
    int? customerId,
    String? date,
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/item_quantity_offers/active').replace(
        queryParameters: {
          'stock_location_id': locationId.toString(),
          if (customerId != null) 'customer_id': customerId.toString(),
          if (date != null) 'date': date,
        },
      );

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];

        if (data != null && data is Map<String, dynamic>) {
          final offersResponse = ActiveOffersResponse.fromJson(data);
          return ApiResponse.success(
            data: offersResponse,
            message: jsonResponse['message'] ?? 'Success',
          );
        } else {
          return ApiResponse.success(
            data: ActiveOffersResponse(offers: [], count: 0),
            message: jsonResponse['message'] ?? 'Success',
          );
        }
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch offers',
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete suspended sale
  Future<ApiResponse<Map<String, dynamic>>> deleteSuspendedSale(int saleId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrlSync/sales/delete/$saleId'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get today's sales summary
  Future<ApiResponse<SaleSummary>> getTodaySummary({String? date}) async {
    try {
      final queryParams = date != null ? {'date': date} : <String, String>{};
      final uri = Uri.parse('$baseUrlSync/sales/today_summary').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<SaleSummary>(
        response,
        (data) => SaleSummary.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== BANKING API ====================

  /// Get Banking list
  Future<ApiResponse<List<BankingListItem>>> getBankingList({
    String? startDate,
    String? endDate,
    int? locationId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (startDate != null) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate;
      }
      if (locationId != null) {
        queryParams['location_id'] = locationId.toString();
      }

      final uri = Uri.parse('$baseUrlSync/banking').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<List<BankingListItem>>(
        response,
        (data) {
          final bankingData = data as Map<String, dynamic>;
          final bankings = bankingData['bankings'] as List;
          return bankings.map((json) => BankingListItem.fromJson(json)).toList();
        },
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create Banking
  Future<ApiResponse<Map<String, dynamic>>> createBanking(BankingCreate banking) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/banking/create'),
        headers: await _getHeaders(),
        body: json.encode(banking.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update Banking
  Future<ApiResponse<BankingListItem>> updateBanking(int id, BankingCreate banking) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrlSync/banking/update/$id'),
        headers: await _getHeaders(),
        body: json.encode(banking.toJson()),
      );

      return _handleResponse<BankingListItem>(
        response,
        (data) => BankingListItem.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete Banking
  Future<ApiResponse<Map<String, dynamic>>> deleteBanking(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrlSync/banking/delete/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== PROFIT SUBMIT API ====================

  /// Get Profit Submissions list
  Future<ApiResponse<Map<String, dynamic>>> getProfitSubmissions({
    String? startDate,
    String? endDate,
    String? stockLocation,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (stockLocation != null) queryParams['stock_location'] = stockLocation;

      final uri = Uri.parse('$baseUrlSync/profitsubmit').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get Profit Submission details
  Future<ApiResponse<ProfitSubmitDetails>> getProfitSubmissionDetails(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/profitsubmit/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<ProfitSubmitDetails>(
        response,
        (data) => ProfitSubmitDetails.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Create Profit Submission
  Future<ApiResponse<Map<String, dynamic>>> createProfitSubmission(ProfitSubmitCreate profitSubmit) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/profitsubmit/create'),
        headers: await _getHeaders(),
        body: json.encode(profitSubmit.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update Profit Submission
  Future<ApiResponse<Map<String, dynamic>>> updateProfitSubmission(int id, ProfitSubmitCreate profitSubmit) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrlSync/profitsubmit/update/$id'),
        headers: await _getHeaders(),
        body: json.encode(profitSubmit.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete Profit Submission
  Future<ApiResponse<Map<String, dynamic>>> deleteProfitSubmission(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrlSync/profitsubmit/delete/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== STOCK LOCATIONS API ====================

  /// Get allowed stock locations for current user
  Future<ApiResponse<List<StockLocation>>> getAllowedStockLocations({
    String moduleId = 'items',
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/stock_locations/allowed')
          .replace(queryParameters: {'module_id': moduleId});

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      return _handleResponse<List<StockLocation>>(
        response,
        (data) {
          final locations = data['locations'] as List;
          return locations.map((loc) => StockLocation.fromJson(loc)).toList();
        },
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get all stock locations
  Future<ApiResponse<List<StockLocation>>> getAllStockLocations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/stock_locations'),
        headers: await _getHeaders(),
      );

      return _handleResponse<List<StockLocation>>(
        response,
        (data) {
          final locations = data['locations'] as List;
          return locations.map((loc) => StockLocation.fromJson(loc)).toList();
        },
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Check if user has access to a location
  Future<ApiResponse<bool>> checkLocationAccess(
    int locationId, {
    String moduleId = 'items',
  }) async {
    try {
      final uri = Uri.parse('$baseUrlSync/stock_locations/check/$locationId')
          .replace(queryParameters: {'module_id': moduleId});

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      return _handleResponse<bool>(
        response,
        (data) => data['is_allowed'] as bool,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== TRANSACTIONS API ====================

  // ---------- CUSTOMER DEPOSITS & WITHDRAWALS ----------

  /// Get customer transaction balance
  Future<ApiResponse<CustomerTransactionBalance>> getCustomerBalance(
    int customerId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/transactions/customer_balance/$customerId')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<CustomerTransactionBalance>(
        response,
        (data) => CustomerTransactionBalance.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get customer statement
  Future<ApiResponse<TransactionStatement>> getCustomerStatement(
    int customerId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/transactions/statement/$customerId')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<TransactionStatement>(
        response,
        (data) => TransactionStatement.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get customer deposits
  Future<ApiResponse<List<Deposit>>> getDeposits({
    int? customerId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final endpoint = customerId != null
          ? 'transactions/deposits/$customerId'
          : 'transactions/deposits';

      final uri = Uri.parse('$baseUrlSync/$endpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final deposits = (data['deposits'] as List)
            .map((item) => Deposit.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: deposits,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch deposits',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get customer withdrawals
  Future<ApiResponse<List<Withdrawal>>> getWithdrawals({
    int? customerId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final endpoint = customerId != null
          ? 'transactions/withdrawals/$customerId'
          : 'transactions/withdrawals';

      final uri = Uri.parse('$baseUrlSync/$endpoint')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final withdrawals = (data['withdrawals'] as List)
            .map((item) => Withdrawal.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: withdrawals,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch withdrawals',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add deposit
  Future<ApiResponse<Map<String, dynamic>>> addDeposit(TransactionFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_deposit'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update deposit
  Future<ApiResponse<Map<String, dynamic>>> updateDeposit(int id, TransactionFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_deposit/$id'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete deposit
  Future<ApiResponse<Map<String, dynamic>>> deleteDeposit(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_deposit/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add withdrawal
  Future<ApiResponse<Map<String, dynamic>>> addWithdrawal(TransactionFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_withdrawal'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update withdrawal
  Future<ApiResponse<Map<String, dynamic>>> updateWithdrawal(int id, TransactionFormData formData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_withdrawal/$id'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete withdrawal
  Future<ApiResponse<Map<String, dynamic>>> deleteWithdrawal(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_withdrawal/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get all customers with balances
  Future<ApiResponse<List<CustomerTransactionBalance>>> getAllCustomersBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/transactions/all_customers_balance'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final customers = (data['customers'] as List)
            .map((item) => CustomerTransactionBalance.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: customers,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch customer balances',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ---------- CASH BASIS ----------

  /// Get cash basis categories
  Future<ApiResponse<List<CashBasisCategory>>> getCashBasisCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/transactions/cash_basis_list'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final categories = (data['cash_basis'] as List)
            .map((item) => CashBasisCategory.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: categories,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch cash basis categories',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add cash basis category
  Future<ApiResponse<Map<String, dynamic>>> addCashBasisCategory({
    required String name,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_cash_basis_category'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          if (description != null) 'description': description,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update cash basis category
  Future<ApiResponse<Map<String, dynamic>>> updateCashBasisCategory(
    int id, {
    String? name,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_cash_basis_category/$id'),
        headers: await _getHeaders(),
        body: json.encode({
          if (name != null) 'name': name,
          if (description != null) 'description': description,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete cash basis category
  Future<ApiResponse<Map<String, dynamic>>> deleteCashBasisCategory(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_cash_basis_category/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get cash basis transactions
  Future<ApiResponse<CashBasisResponse>> getCashBasisTransactions({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/transactions/cash_basis')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<CashBasisResponse>(
        response,
        (data) => CashBasisResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add cash basis transaction
  Future<ApiResponse<Map<String, dynamic>>> addCashBasisTransaction({
    required int cashBasisId,
    required double amount,
    required String date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_cash_basis'),
        headers: await _getHeaders(),
        body: json.encode({
          'cash_basis_id': cashBasisId,
          'amount': amount,
          'date': date,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update cash basis transaction
  Future<ApiResponse<Map<String, dynamic>>> updateCashBasisTransaction(
    int id, {
    int? cashBasisId,
    double? amount,
    String? date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_cash_basis/$id'),
        headers: await _getHeaders(),
        body: json.encode({
          if (cashBasisId != null) 'cash_basis_id': cashBasisId,
          if (amount != null) 'amount': amount,
          if (date != null) 'date': date,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete cash basis transaction
  Future<ApiResponse<Map<String, dynamic>>> deleteCashBasisTransaction(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_cash_basis/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ---------- BANK BASIS ----------

  /// Get bank basis categories
  Future<ApiResponse<List<BankBasisCategory>>> getBankBasisCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/transactions/bank_basis_list'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final categories = (data['bank_basis'] as List)
            .map((item) => BankBasisCategory.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: categories,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch bank basis categories',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add bank basis category
  Future<ApiResponse<Map<String, dynamic>>> addBankBasisCategory({
    required String name,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_bank_basis_category'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          if (description != null) 'description': description,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update bank basis category
  Future<ApiResponse<Map<String, dynamic>>> updateBankBasisCategory(
    int id, {
    String? name,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_bank_basis_category/$id'),
        headers: await _getHeaders(),
        body: json.encode({
          if (name != null) 'name': name,
          if (description != null) 'description': description,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete bank basis category
  Future<ApiResponse<Map<String, dynamic>>> deleteBankBasisCategory(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_bank_basis_category/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get bank basis transactions
  Future<ApiResponse<BankBasisResponse>> getBankBasisTransactions({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/transactions/bank_basis')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<BankBasisResponse>(
        response,
        (data) => BankBasisResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add bank basis transaction
  Future<ApiResponse<Map<String, dynamic>>> addBankBasisTransaction({
    required int bankBasisId,
    required double amount,
    required String date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_bank_basis'),
        headers: await _getHeaders(),
        body: json.encode({
          'bank_basis_id': bankBasisId,
          'amount': amount,
          'date': date,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update bank basis transaction
  Future<ApiResponse<Map<String, dynamic>>> updateBankBasisTransaction(
    int id, {
    int? bankBasisId,
    double? amount,
    String? date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_bank_basis/$id'),
        headers: await _getHeaders(),
        body: json.encode({
          if (bankBasisId != null) 'bank_basis_id': bankBasisId,
          if (amount != null) 'amount': amount,
          if (date != null) 'date': date,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete bank basis transaction
  Future<ApiResponse<Map<String, dynamic>>> deleteBankBasisTransaction(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_bank_basis/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ---------- WAKALA / SIMs ----------

  /// Get SIM cards
  Future<ApiResponse<List<Sim>>> getSims() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/transactions/sims'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final sims = (data['sims'] as List)
            .map((item) => Sim.fromJson(item))
            .toList();

        return ApiResponse.success(
          data: sims,
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch SIMs',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add SIM card
  Future<ApiResponse<Map<String, dynamic>>> addSim({
    required String name,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_sim'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          if (description != null) 'description': description,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update SIM card
  Future<ApiResponse<Map<String, dynamic>>> updateSim(
    int id, {
    String? name,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_sim/$id'),
        headers: await _getHeaders(),
        body: json.encode({
          if (name != null) 'name': name,
          if (description != null) 'description': description,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete SIM card
  Future<ApiResponse<Map<String, dynamic>>> deleteSim(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_sim/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get wakala transactions
  Future<ApiResponse<WakalaResponse>> getWakalaTransactions({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/transactions/wakala')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<WakalaResponse>(
        response,
        (data) => WakalaResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add wakala transaction
  Future<ApiResponse<Map<String, dynamic>>> addWakalaTransaction({
    required int simId,
    required double amount,
    required String date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_wakala'),
        headers: await _getHeaders(),
        body: json.encode({
          'sim_id': simId,
          'amount': amount,
          'date': date,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update wakala transaction
  Future<ApiResponse<Map<String, dynamic>>> updateWakalaTransaction(
    int id, {
    int? simId,
    double? amount,
    String? date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_wakala/$id'),
        headers: await _getHeaders(),
        body: json.encode({
          if (simId != null) 'sim_id': simId,
          if (amount != null) 'amount': amount,
          if (date != null) 'date': date,
        }),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete wakala transaction
  Future<ApiResponse<Map<String, dynamic>>> deleteWakalaTransaction(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_wakala/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get wakala report
  Future<ApiResponse<WakalaReport>> getWakalaReport({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/transactions/wakala_report')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<WakalaReport>(
        response,
        (data) => WakalaReport.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get wakala expenses
  Future<ApiResponse<WakalaExpenseResponse>> getWakalaExpenses({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/transactions/wakala_expenses')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<WakalaExpenseResponse>(
        response,
        (data) => WakalaExpenseResponse.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Add wakala expense
  Future<ApiResponse<Map<String, dynamic>>> addWakalaExpense(
    WakalaExpenseFormData formData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/add_wakala_expense'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update wakala expense
  Future<ApiResponse<Map<String, dynamic>>> updateWakalaExpense(
    int id,
    WakalaExpenseFormData formData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/update_wakala_expense/$id'),
        headers: await _getHeaders(),
        body: json.encode(formData.toJson()),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Delete wakala expense
  Future<ApiResponse<Map<String, dynamic>>> deleteWakalaExpense(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrlSync/transactions/delete_wakala_expense/$id'),
        headers: await _getHeaders(),
      );

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get total wakala expenses
  Future<ApiResponse<Map<String, dynamic>>> getWakalaExpensesTotal({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/transactions/wakala_expenses_total')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<Map<String, dynamic>>(
        response,
        (data) => data,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ==================== REPORTS API ====================

  /// Get report data (generic method for all report types)
  Future<ApiResponse<ReportData>> getReport(
    ReportType reportType, {
    String? startDate,
    String? endDate,
    int? locationId,
    String? saleType,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (locationId != null) queryParams['location_id'] = locationId.toString();
      if (saleType != null) queryParams['sale_type'] = saleType;

      final uri = Uri.parse('$baseUrlSync/${reportType.apiPath}')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<ReportData>(
        response,
        (data) => ReportData.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get summary sales report
  Future<ApiResponse<ReportData>> getSummarySalesReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summarySales,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary items report
  Future<ApiResponse<ReportData>> getSummaryItemsReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summaryItems,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary categories report
  Future<ApiResponse<ReportData>> getSummaryCategoriesReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summaryCategories,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary customers report
  Future<ApiResponse<ReportData>> getSummaryCustomersReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summaryCustomers,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary employees report
  Future<ApiResponse<ReportData>> getSummaryEmployeesReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summaryEmployees,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary payments report
  Future<ApiResponse<ReportData>> getSummaryPaymentsReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summaryPayments,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary expenses report
  Future<ApiResponse<ReportData>> getSummaryExpensesReport({
    required String startDate,
    required String endDate,
    int? locationId,
  }) async {
    return getReport(
      ReportType.summaryExpenses,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
    );
  }

  /// Get summary discounts report
  Future<ApiResponse<ReportData>> getSummaryDiscountsReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summaryDiscounts,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary taxes report
  Future<ApiResponse<ReportData>> getSummaryTaxesReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summaryTaxes,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary sales taxes report
  Future<ApiResponse<ReportData>> getSummarySalesTaxesReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.summarySalesTaxes,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get summary suppliers report
  Future<ApiResponse<ReportData>> getSummarySuppliersReport({
    required String startDate,
    required String endDate,
    int? locationId,
  }) async {
    return getReport(
      ReportType.summarySuppliers,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
    );
  }

  /// Get detailed sales report
  Future<ApiResponse<ReportData>> getDetailedSalesReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.detailedSales,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get detailed receivings report
  Future<ApiResponse<ReportData>> getDetailedReceivingsReport({
    required String startDate,
    required String endDate,
    int? locationId,
  }) async {
    return getReport(
      ReportType.detailedReceivings,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
    );
  }

  /// Get detailed customers report
  Future<ApiResponse<ReportData>> getDetailedCustomersReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.detailedCustomers,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get detailed employees report
  Future<ApiResponse<ReportData>> getDetailedEmployeesReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.detailedEmployees,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get detailed discounts report
  Future<ApiResponse<ReportData>> getDetailedDiscountsReport({
    required String startDate,
    required String endDate,
    int? locationId,
    String? saleType,
  }) async {
    return getReport(
      ReportType.detailedDiscounts,
      startDate: startDate,
      endDate: endDate,
      locationId: locationId,
      saleType: saleType,
    );
  }

  /// Get inventory summary report
  Future<ApiResponse<ReportData>> getInventorySummaryReport({
    int? locationId,
    String? search,
    String? itemCount,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (locationId != null) queryParams['location_id'] = locationId.toString();
      if (search != null) queryParams['search'] = search;
      if (itemCount != null) queryParams['item_count'] = itemCount;

      final uri = Uri.parse('$baseUrlSync/reports/inventory/summary')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<ReportData>(
        response,
        (data) => ReportData.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get low stock report
  Future<ApiResponse<ReportData>> getLowStockReport({
    int? locationId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/reports/inventory/low')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<ReportData>(
        response,
        (data) => ReportData.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get specific customer report
  Future<ApiResponse<SpecificReportData>> getSpecificCustomerReport(
    int customerId, {
    required String startDate,
    required String endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'start_date': startDate,
        'end_date': endDate,
      };

      final uri = Uri.parse('$baseUrlSync/reports/specific/customer/$customerId')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<SpecificReportData>(
        response,
        (data) => SpecificReportData.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get specific employee report
  Future<ApiResponse<SpecificReportData>> getSpecificEmployeeReport(
    int employeeId, {
    required String startDate,
    required String endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'start_date': startDate,
        'end_date': endDate,
      };

      final uri = Uri.parse('$baseUrlSync/reports/specific/employee/$employeeId')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<SpecificReportData>(
        response,
        (data) => SpecificReportData.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get graphical report data
  Future<ApiResponse<GraphicalReportData>> getGraphicalReport(
    String reportType, {
    required String startDate,
    required String endDate,
    int? locationId,
  }) async {
    try {
      final queryParams = <String, String>{
        'start_date': startDate,
        'end_date': endDate,
      };
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/reports/graphical/$reportType')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse<GraphicalReportData>(
        response,
        (data) => GraphicalReportData.fromJson(data),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get report locations (for dropdown)
  Future<ApiResponse<List<StockLocation>>> getReportLocations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/reports/locations'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'] as List;
        final locations = data.map((loc) => StockLocation.fromJson(loc)).toList();

        return ApiResponse.success(
          data: locations,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch locations',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get receiving items for a specific receiving
  Future<ApiResponse<List<Map<String, dynamic>>>> getReceivingItems(int receivingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/reports/receiving_items/$receivingId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final items = (data['items'] as List).cast<Map<String, dynamic>>();

        return ApiResponse.success(
          data: items,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch receiving items',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ========================================
  // Stock Tracking APIs
  // ========================================

  /// Get stock tracking report for a specific date and location
  Future<ApiResponse<StockTrackingReport>> getStockTracking({
    required String date,
    required int stockLocationId,
  }) async {
    final url = '$baseUrlSync/stock/tracking?date=$date&stock_location_id=$stockLocationId';
    print('=== API: getStockTracking ===');
    print('URL: $url');

    try {
      final headers = await _getHeaders();
      print('Headers: $headers');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        print('Parsing StockTrackingReport from data...');
        final report = StockTrackingReport.fromJson(data);
        print('Report parsed successfully - Items: ${report.items.length}');

        return ApiResponse.success(
          data: report,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        print('ERROR: ${jsonResponse['message']}');
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch stock tracking',
          statusCode: response.statusCode,
        );
      }
    } catch (e, stackTrace) {
      print('EXCEPTION: $e');
      print('Stack trace: $stackTrace');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get item tracking report for a specific item
  Future<ApiResponse<ItemTrackingReport>> getItemTracking({
    required String startDate,
    required String endDate,
    required int itemId,
    required int stockLocationId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/stock/item_tracking?start_date=$startDate&end_date=$endDate&item_id=$itemId&stock_location_id=$stockLocationId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final report = ItemTrackingReport.fromJson(data);

        return ApiResponse.success(
          data: report,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch item tracking',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get items list for dropdown selection in stock tracking
  Future<ApiResponse<List<SimpleItem>>> getStockItems({
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      var url = '$baseUrlSync/stock/items?limit=$limit&offset=$offset';
      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'] as List;
        final items = data.map((item) => SimpleItem.fromJson(item)).toList();

        return ApiResponse.success(
          data: items,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch items',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get stock locations for stock tracking
  Future<ApiResponse<List<StockLocation>>> getStockTrackingLocations() async {
    final url = '$baseUrlSync/stock/locations';
    print('=== API: getStockTrackingLocations ===');
    print('URL: $url');

    try {
      final headers = await _getHeaders();
      print('Headers: $headers');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'] as List;
        final locations = data.map((loc) => StockLocation.fromJson(loc)).toList();

        print('Parsed ${locations.length} locations');
        return ApiResponse.success(
          data: locations,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        print('ERROR: ${jsonResponse['message']}');
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch locations',
          statusCode: response.statusCode,
        );
      }
    } catch (e, stackTrace) {
      print('EXCEPTION: $e');
      print('Stack trace: $stackTrace');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ========================================
  // Positions APIs
  // ========================================

  /// Get daily financial positions report
  Future<ApiResponse<PositionsReport>> getPositions({
    required String startDate,
    required String endDate,
    int? stockLocationId,
  }) async {
    try {
      var url = '$baseUrlSync/positions?start_date=$startDate&end_date=$endDate';
      if (stockLocationId != null) {
        url += '&stock_location_id=$stockLocationId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final report = PositionsReport.fromJson(data);

        return ApiResponse.success(
          data: report,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch positions',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get position summary for a specific date
  Future<ApiResponse<DailyPosition>> getPositionSummary({
    required String date,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/positions/summary?date=$date'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final position = DailyPosition.fromJson(data);

        return ApiResponse.success(
          data: position,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch position summary',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // ============================================================================
  // COMMISSION DASHBOARD (Leruma-specific)
  // ============================================================================

  /// Get full commission dashboard data (Leruma only)
  /// Includes caching for improved performance (60 second TTL)
  Future<ApiResponse<Map<String, dynamic>>> getCommissionDashboard({
    String? startDate,
    String? endDate,
    int? locationId,
    bool forceRefresh = false,
  }) async {
    // Check cache first (if not force refresh)
    if (!forceRefresh && _dashboardCache != null && _dashboardCacheTime != null) {
      final cacheAge = DateTime.now().difference(_dashboardCacheTime!).inSeconds;
      if (cacheAge < _cacheTTLSeconds) {
        print('📦 Using cached dashboard data (age: ${cacheAge}s)');
        return ApiResponse.success(
          data: _dashboardCache!,
          message: 'Success (cached)',
        );
      }
    }

    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/dashboard').replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      print('📊 Fetching commission dashboard: $uri');

      final response = await http.get(uri, headers: await _getHeaders());

      print('📥 Dashboard response status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'] as Map<String, dynamic>;

        // Cache the response
        _dashboardCache = data;
        _dashboardCacheTime = DateTime.now();
        print('💾 Dashboard data cached');

        return ApiResponse.success(
          data: data,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch dashboard',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('❌ Dashboard error: $e');
      // Return cached data on network error if available
      if (_dashboardCache != null) {
        print('📦 Network error, using cached data');
        return ApiResponse.success(
          data: _dashboardCache!,
          message: 'Success (offline cache)',
        );
      }
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Clear dashboard cache (call when user logs out or switches client)
  static void clearDashboardCache() {
    _dashboardCache = null;
    _dashboardCacheTime = null;
    print('🗑️ Dashboard cache cleared');
  }

  /// Get commission progress for all levels (Leruma only)
  Future<ApiResponse<Map<String, dynamic>>> getCommissionProgress({
    String? startDate,
    String? endDate,
    int? locationId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/dashboard/commission').replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          data: jsonResponse['data'] as Map<String, dynamic>,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch commission progress',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get recent activity for dashboard (Leruma only)
  Future<ApiResponse<List<Map<String, dynamic>>>> getDashboardActivity({
    int? locationId,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/dashboard/activity').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];
        return ApiResponse.success(
          data: data.map((e) => e as Map<String, dynamic>).toList(),
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch activity',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // =====================================================
  // NFC CUSTOMER CARD ENDPOINTS
  // =====================================================

  /// Get customer by NFC card UID
  Future<ApiResponse<Customer>> getCustomerByCardUid(String cardUid) async {
    try {
      debugPrint('🔍 Looking up customer by card UID: $cardUid');

      final uri = Uri.parse('$baseUrlSync/customer_cards/lookup').replace(
        queryParameters: {'card_uid': cardUid},
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);

        // Handle nested response: {status, data: {success, data: {...}}}
        var rawData = jsonResponse['data'];
        if (rawData is Map && rawData['data'] != null) {
          // Check if inner success is true
          if (rawData['success'] == true) {
            return ApiResponse.success(
              data: Customer.fromJson(rawData['data']),
              message: jsonResponse['message'] ?? 'Customer found',
            );
          } else {
            return ApiResponse.error(message: rawData['message'] ?? 'Card not registered');
          }
        } else if (rawData != null) {
          return ApiResponse.success(
            data: Customer.fromJson(rawData),
            message: jsonResponse['message'] ?? 'Customer found',
          );
        }
        return ApiResponse.error(message: 'Card not registered');
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Customer not found',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ Error looking up customer by card: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Register a new NFC card for a customer
  Future<ApiResponse<CustomerCard>> registerCustomerCard({
    required int customerId,
    required String cardUid,
    String cardType = 'nfc',
  }) async {
    try {
      debugPrint('📝 Registering card $cardUid for customer $customerId');

      final response = await http.post(
        Uri.parse('$baseUrlSync/customer_cards'),
        headers: await _getHeaders(),
        body: json.encode({
          'customer_id': customerId,
          'card_uid': cardUid,
          'card_type': cardType,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          data: CustomerCard.fromJson(jsonResponse['data']),
          message: jsonResponse['message'] ?? 'Card registered successfully',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to register card',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ Error registering card: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Unregister/deactivate a customer card
  Future<ApiResponse<void>> unregisterCustomerCard(int cardId) async {
    try {
      debugPrint('🗑️ Unregistering card $cardId');

      final response = await http.delete(
        Uri.parse('$baseUrlSync/customer_cards/$cardId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.success(
          message: jsonResponse['message'] ?? 'Card unregistered successfully',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to unregister card',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ Error unregistering card: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get all cards for a customer
  Future<ApiResponse<List<CustomerCard>>> getCustomerCards(int customerId) async {
    try {
      debugPrint('📋 Getting cards for customer $customerId');

      final uri = Uri.parse('$baseUrlSync/customer_cards').replace(
        queryParameters: {'customer_id': customerId.toString()},
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);

        // Handle nested response format: {status, data: {success, data: [...]}}
        var rawData = jsonResponse['data'];
        List<dynamic> data = [];

        // Check if data is nested (API_Controller wraps response)
        if (rawData is Map && rawData['data'] != null) {
          rawData = rawData['data'];
        }

        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map) {
          debugPrint('⚠️ getCustomerCards: data is Map, treating as empty');
        }

        debugPrint('📋 Found ${data.length} cards for customer $customerId');

        return ApiResponse.success(
          data: data.map((e) => CustomerCard.fromJson(e)).toList(),
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to get cards',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ Error getting customer cards: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get all registered cards (admin)
  Future<ApiResponse<List<CustomerCard>>> getAllCustomerCards({
    int? locationId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/customer_cards/all').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);

        // Handle nested response format: {status, data: {success, data: [...]}}
        var rawData = jsonResponse['data'];
        List<dynamic> data = [];

        // Check if data is nested (API_Controller wraps response)
        if (rawData is Map && rawData['data'] != null) {
          rawData = rawData['data'];
        }

        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map) {
          debugPrint('⚠️ getAllCustomerCards: data is Map, treating as empty');
        }

        return ApiResponse.success(
          data: data.map((e) => CustomerCard.fromJson(e)).toList(),
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to get cards',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ Error getting all cards: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  // =====================================================
  // NFC WALLET API METHODS
  // =====================================================

  /// Get NFC card balance
  Future<ApiResponse<NfcCardBalance>> getNfcCardBalance(String cardUid) async {
    try {
      debugPrint('💳 Getting NFC card balance for: $cardUid');

      final uri = Uri.parse('$baseUrlSync/nfc_wallet/balance').replace(
        queryParameters: {'card_uid': cardUid},
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        // Handle nested response
        if (rawData is Map && rawData['data'] != null && rawData['success'] == true) {
          return ApiResponse.success(
            data: NfcCardBalance.fromJson(rawData['data']),
            message: 'Success',
          );
        } else if (rawData is Map && rawData['success'] == false) {
          return ApiResponse.error(message: rawData['message'] ?? 'Card not found');
        }

        return ApiResponse.error(message: 'Card not found');
      } else {
        return ApiResponse.error(message: 'Failed to get card balance');
      }
    } catch (e) {
      debugPrint('❌ Error getting card balance: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Deposit money to NFC card
  Future<ApiResponse<NfcTransactionResult>> depositToNfcCard({
    required String cardUid,
    required double amount,
    String? description,
    int? locationId,
  }) async {
    try {
      debugPrint('💰 Depositing $amount to card: $cardUid');

      final response = await http.post(
        Uri.parse('$baseUrlSync/nfc_wallet/deposit'),
        headers: await _getHeaders(),
        body: json.encode({
          'card_uid': cardUid,
          'amount': amount,
          'description': description ?? 'Deposit',
          'location_id': locationId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        if (rawData is Map && rawData['success'] == true && rawData['data'] != null) {
          return ApiResponse.success(
            data: NfcTransactionResult.fromJson(rawData['data']),
            message: rawData['message'] ?? 'Deposit successful',
          );
        }

        return ApiResponse.error(message: rawData?['message'] ?? 'Deposit failed');
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(message: jsonResponse['message'] ?? 'Deposit failed');
      }
    } catch (e) {
      debugPrint('❌ Error depositing: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Make payment from NFC card balance
  Future<ApiResponse<NfcTransactionResult>> payWithNfcCard({
    required String cardUid,
    required double amount,
    int? saleId,
    String? description,
    int? locationId,
  }) async {
    try {
      debugPrint('💳 Paying $amount with card: $cardUid');

      final response = await http.post(
        Uri.parse('$baseUrlSync/nfc_wallet/payment'),
        headers: await _getHeaders(),
        body: json.encode({
          'card_uid': cardUid,
          'amount': amount,
          'sale_id': saleId,
          'description': description ?? 'Payment',
          'location_id': locationId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        if (rawData is Map && rawData['success'] == true && rawData['data'] != null) {
          return ApiResponse.success(
            data: NfcTransactionResult.fromJson(rawData['data']),
            message: rawData['message'] ?? 'Payment successful',
          );
        } else if (rawData is Map && rawData['success'] == false) {
          // Check for insufficient balance
          if (rawData['data'] != null && rawData['data']['shortage'] != null) {
            final shortage = rawData['data'];
            return ApiResponse.error(
              message: 'Insufficient balance. Need ${shortage['required']}, have ${shortage['available']}',
            );
          }
          return ApiResponse.error(message: rawData['message'] ?? 'Payment failed');
        }

        return ApiResponse.error(message: 'Payment failed');
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(message: jsonResponse['message'] ?? 'Payment failed');
      }
    } catch (e) {
      debugPrint('❌ Error paying: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Confirm credit sale with NFC card
  Future<ApiResponse<NfcConfirmationResult>> confirmCreditSaleWithNfc({
    required String cardUid,
    required double amount,
    int? saleId,
    int? locationId,
  }) async {
    try {
      debugPrint('✅ Confirming credit sale $amount with card: $cardUid');

      final response = await http.post(
        Uri.parse('$baseUrlSync/nfc_wallet/confirm_credit'),
        headers: await _getHeaders(),
        body: json.encode({
          'card_uid': cardUid,
          'amount': amount,
          'sale_id': saleId,
          'location_id': locationId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        if (rawData is Map && rawData['success'] == true && rawData['data'] != null) {
          return ApiResponse.success(
            data: NfcConfirmationResult.fromJson(rawData['data']),
            message: rawData['message'] ?? 'Credit sale confirmed',
          );
        }

        return ApiResponse.error(message: rawData?['message'] ?? 'Confirmation failed');
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(message: jsonResponse['message'] ?? 'Confirmation failed');
      }
    } catch (e) {
      debugPrint('❌ Error confirming credit: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Confirm payment with NFC card
  Future<ApiResponse<NfcConfirmationResult>> confirmPaymentWithNfc({
    required String cardUid,
    required double amount,
    int? paymentId,
    int? locationId,
  }) async {
    try {
      debugPrint('✅ Confirming payment $amount with card: $cardUid');

      final response = await http.post(
        Uri.parse('$baseUrlSync/nfc_wallet/confirm_payment'),
        headers: await _getHeaders(),
        body: json.encode({
          'card_uid': cardUid,
          'amount': amount,
          'payment_id': paymentId,
          'location_id': locationId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        if (rawData is Map && rawData['success'] == true && rawData['data'] != null) {
          return ApiResponse.success(
            data: NfcConfirmationResult.fromJson(rawData['data']),
            message: rawData['message'] ?? 'Payment confirmed',
          );
        }

        return ApiResponse.error(message: rawData?['message'] ?? 'Confirmation failed');
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(message: jsonResponse['message'] ?? 'Confirmation failed');
      }
    } catch (e) {
      debugPrint('❌ Error confirming payment: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get NFC card statement
  Future<ApiResponse<NfcStatement>> getNfcStatement({
    required String cardUid,
    String? startDate,
    String? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      debugPrint('📊 Getting NFC statement for: $cardUid');

      final queryParams = <String, String>{
        'card_uid': cardUid,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrlSync/nfc_wallet/statement').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        if (rawData is Map && rawData['success'] == true && rawData['data'] != null) {
          return ApiResponse.success(
            data: NfcStatement.fromJson(rawData['data']),
            message: 'Success',
          );
        }

        return ApiResponse.error(message: rawData?['message'] ?? 'Failed to get statement');
      } else {
        return ApiResponse.error(message: 'Failed to get statement');
      }
    } catch (e) {
      debugPrint('❌ Error getting statement: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get NFC confirmations report
  Future<ApiResponse<List<NfcConfirmation>>> getNfcConfirmations({
    String? startDate,
    String? endDate,
    String? type,
    int? customerId,
    int? employeeId,
    int? locationId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      debugPrint('📋 Getting NFC confirmations');

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (type != null) queryParams['type'] = type;
      if (customerId != null) queryParams['customer_id'] = customerId.toString();
      if (employeeId != null) queryParams['employee_id'] = employeeId.toString();
      if (locationId != null) queryParams['location_id'] = locationId.toString();

      final uri = Uri.parse('$baseUrlSync/nfc_wallet/confirmations').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        if (rawData is Map && rawData['success'] == true && rawData['data'] != null) {
          final confirmationsData = rawData['data']['confirmations'] as List<dynamic>? ?? [];
          return ApiResponse.success(
            data: confirmationsData.map((e) => NfcConfirmation.fromJson(e)).toList(),
            message: 'Success',
          );
        }

        return ApiResponse.error(message: 'Failed to get confirmations');
      } else {
        return ApiResponse.error(message: 'Failed to get confirmations');
      }
    } catch (e) {
      debugPrint('❌ Error getting confirmations: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Update customer NFC settings
  Future<ApiResponse<void>> updateCustomerNfcSettings({
    required int customerId,
    bool? nfcConfirmRequired,
    bool? nfcPaymentEnabled,
  }) async {
    try {
      debugPrint('⚙️ Updating NFC settings for customer: $customerId');

      final response = await http.post(
        Uri.parse('$baseUrlSync/nfc_wallet/customer_settings'),
        headers: await _getHeaders(),
        body: json.encode({
          'customer_id': customerId,
          if (nfcConfirmRequired != null) 'nfc_confirm_required': nfcConfirmRequired,
          if (nfcPaymentEnabled != null) 'nfc_payment_enabled': nfcPaymentEnabled,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        if (rawData is Map && rawData['success'] == true) {
          return ApiResponse.success(message: 'Settings updated');
        }

        return ApiResponse.error(message: rawData?['message'] ?? 'Failed to update settings');
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(message: jsonResponse['message'] ?? 'Failed to update settings');
      }
    } catch (e) {
      debugPrint('❌ Error updating settings: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Get customer NFC settings
  Future<ApiResponse<NfcCustomerSettings>> getCustomerNfcSettings(int customerId) async {
    try {
      debugPrint('⚙️ Getting NFC settings for customer: $customerId');

      final uri = Uri.parse('$baseUrlSync/nfc_wallet/get_customer_settings').replace(
        queryParameters: {'customer_id': customerId.toString()},
      );

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        var rawData = jsonResponse['data'];

        if (rawData is Map && rawData['success'] == true && rawData['data'] != null) {
          return ApiResponse.success(
            data: NfcCustomerSettings.fromJson(rawData['data']),
            message: 'Success',
          );
        }

        return ApiResponse.error(message: rawData?['message'] ?? 'Customer not found');
      } else {
        return ApiResponse.error(message: 'Failed to get settings');
      }
    } catch (e) {
      debugPrint('❌ Error getting settings: $e');
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }
}
