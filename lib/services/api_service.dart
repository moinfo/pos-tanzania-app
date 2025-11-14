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
import '../config/clients_config.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  String? _token;

  // Make currentClient public so it can be accessed from main_navigation
  static ClientConfig? currentClient;

  // Get current client configuration
  static Future<ClientConfig> getCurrentClient() async {
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('selected_client_id');

    print('🔄 Loading client from preferences: $clientId');

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
    _token ??= await _storage.read(key: 'auth_token');
    return _token;
  }

  // Save token
  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'auth_token', value: token);
  }

  // Clear token
  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
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
    required String a,
    required String c,
    required String date,
    int? stockLocationId,
    required String picFile, // Base64 encoded file
  }) async {
    try {
      final body = <String, dynamic>{
        'a': a,
        'c': c,
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
    required String a,
    required String c,
    required String date,
    int? stockLocationId,
    String? picFile, // Optional base64 encoded file
  }) async {
    try {
      final body = <String, dynamic>{
        'a': a,
        'c': c,
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
  Future<ApiResponse<Map<String, dynamic>>> getCashSubmitTodaySummary({String? date}) async {
    try {
      final queryParams = date != null ? '?date=$date' : '';

      final response = await http.get(
        Uri.parse('$baseUrlSync/cashsubmit/today_summary$queryParams'),
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
          message: jsonResponse['message'] ?? 'Failed to fetch today summary',
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
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (search != null) 'search': search,
        if (supervisorId != null) 'supervisor_id': supervisorId,
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
}
