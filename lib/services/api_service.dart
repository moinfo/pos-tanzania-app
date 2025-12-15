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
    // In RELEASE mode: Always use PRODUCTION_CLIENT_ID (ignore SharedPreferences)
    if (kReleaseMode) {
      currentClient = ClientsConfig.getClientById(ClientsConfig.PRODUCTION_CLIENT_ID);
      currentClient ??= ClientsConfig.getDefaultClient();
      print('🏭 RELEASE MODE: Using production client: ${currentClient?.displayName} (${currentClient?.id})');
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

      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final items = (data['items'] as List)
            .map((item) => Item.fromJson(item))
            .toList();

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
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/stock/tracking?date=$date&stock_location_id=$stockLocationId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'];
        final report = StockTrackingReport.fromJson(data);

        return ApiResponse.success(
          data: report,
          message: jsonResponse['message'] ?? 'Success',
        );
      } else {
        final jsonResponse = json.decode(response.body);
        return ApiResponse.error(
          message: jsonResponse['message'] ?? 'Failed to fetch stock tracking',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
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
    try {
      final response = await http.get(
        Uri.parse('$baseUrlSync/stock/locations'),
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
}
