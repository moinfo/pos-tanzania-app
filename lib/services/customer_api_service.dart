import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/api_response.dart';
import '../models/contract.dart';
import '../models/portal_contract_detail.dart';
import '../models/monthly_payment_total.dart';
import 'api_service.dart';

/// Backs the customer self-service portal's "customer mode" inside this
/// app -- a completely separate login from staff (ApiService.login()),
/// hitting api/portal/* (Customer_API_Controller on the backend, a token
/// type staff credentials can never authenticate against and vice versa).
/// Deliberately self-contained rather than folded into ApiService: it has
/// its own storage keys (customer_auth_token/customer_tenant_code/
/// customer_phone) so a staff session and a customer session can coexist
/// on the same device without either clobbering the other.
class CustomerApiService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'customer_auth_token';
  static const _tenantCodeKey = 'customer_tenant_code';
  static const _tenantNameKey = 'customer_tenant_name';
  static const _phoneKey = 'customer_phone';

  String get _baseUrl => ApiService.baseUrlSync;

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getTenantCode() => _storage.read(key: _tenantCodeKey);
  Future<String?> getTenantName() => _storage.read(key: _tenantNameKey);
  Future<String?> getPhone() => _storage.read(key: _phoneKey);

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  Future<void> _saveSession(Map<String, dynamic> data) async {
    await _storage.write(key: _tokenKey, value: data['token'] as String);
    await _storage.write(
        key: _tenantCodeKey, value: data['tenant_code'] as String);
    await _storage.write(
        key: _tenantNameKey, value: data['tenant_name'] as String? ?? '');
    await _storage.write(key: _phoneKey, value: data['phone'] as String? ?? '');
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tenantCodeKey);
    await _storage.delete(key: _tenantNameKey);
    await _storage.delete(key: _phoneKey);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  ApiResponse<T> _handle<T>(
      http.Response response, T Function(dynamic data) parser) {
    try {
      final body = json.decode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body['status'] == 'success') {
        return ApiResponse.success(
          data: parser(body['data']),
          message: body['message'] as String? ?? 'Success',
        );
      }
      return ApiResponse.error(
          message: body['message'] as String? ?? 'Request failed');
    } catch (e) {
      return ApiResponse.error(message: 'Unexpected response: $e');
    }
  }

  /// Step 1 of registration -- sends an OTP if eligible. The response is
  /// deliberately the same whether or not an OTP was actually sent (the
  /// backend doesn't reveal which), so there's nothing case-specific to
  /// branch on here beyond success/failure of the request itself.
  Future<ApiResponse<Map<String, dynamic>>> register({
    required String tenantCode,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/portal/register'),
        headers: await _headers(auth: false),
        body: json.encode(
            {'tenant_code': tenantCode, 'phone': phone, 'password': password}),
      );
      return _handle<Map<String, dynamic>>(response, (data) => data ?? {});
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Step 2: OTP -> activates the account and logs in.
  Future<ApiResponse<Map<String, dynamic>>> verifyRegistration({
    required String tenantCode,
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/portal/verify-registration'),
        headers: await _headers(auth: false),
        body: json
            .encode({'tenant_code': tenantCode, 'phone': phone, 'otp': otp}),
      );
      final result =
          _handle<Map<String, dynamic>>(response, (data) => data ?? {});
      if (result.isSuccess && result.data != null) {
        await _saveSession(result.data!);
      }
      return result;
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// [tenantCode] is optional -- a customer no more knows which tenant
  /// they belong to than staff do, so when it's omitted the backend tries
  /// every tenant with an active account matching the phone number.
  Future<ApiResponse<Map<String, dynamic>>> login({
    String? tenantCode,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/portal/login'),
        headers: await _headers(auth: false),
        body: json.encode({
          if (tenantCode != null && tenantCode.isNotEmpty)
            'tenant_code': tenantCode,
          'phone': phone,
          'password': password,
        }),
      );
      final result =
          _handle<Map<String, dynamic>>(response, (data) => data ?? {});
      if (result.isSuccess && result.data != null) {
        await _saveSession(result.data!);
      }
      return result;
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> requestPasswordReset({
    required String tenantCode,
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/portal/forgot-password'),
        headers: await _headers(auth: false),
        body: json.encode({'tenant_code': tenantCode, 'phone': phone}),
      );
      return _handle<Map<String, dynamic>>(response, (data) => data ?? {});
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String tenantCode,
    required String phone,
    required String otp,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/portal/reset-password'),
        headers: await _headers(auth: false),
        body: json.encode({
          'tenant_code': tenantCode,
          'phone': phone,
          'otp': otp,
          'password': password,
        }),
      );
      return _handle<Map<String, dynamic>>(response, (data) => data ?? {});
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<List<Contract>>> getContracts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/portal/contracts'),
        headers: await _headers(),
      );
      return _handle<List<Contract>>(response, (data) {
        final list = (data['contracts'] as List?) ?? [];
        return list
            .map((e) => Contract.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<PortalContractDetail>> getContractDetail(
      int contractId) async {
    try {
      final uri = Uri.parse('$_baseUrl/portal/contracts/$contractId');
      final response = await http.get(uri, headers: await _headers());
      return _handle<PortalContractDetail>(
        response,
        (data) => PortalContractDetail.fromJson(data as Map<String, dynamic>),
      );
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// The classic date-ranged credit/debit/balance/opening/closing statement
  /// -- same api/Portal::contract() endpoint as getContractDetail(), just
  /// asking for the day-by-day `statement` field with an explicit date
  /// range instead of the stat-card fields. Backend defaults to the
  /// current month when start/end are omitted.
  Future<ApiResponse<ContractStatement>> getContractStatement(
    int contractId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final params = <String, String>{
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      };
      final uri = Uri.parse('$_baseUrl/portal/contracts/$contractId')
          .replace(queryParameters: params.isEmpty ? null : params);
      final response = await http.get(uri, headers: await _headers());
      return _handle<ContractStatement>(response, (data) {
        final statementList = (data['statement'] as List?) ?? [];
        return ContractStatement(
          contract: Contract.fromJson(data as Map<String, dynamic>),
          statement: statementList
              .map((e) => StatementEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
          startDate: data['start_date'] as String? ?? '',
          endDate: data['end_date'] as String? ?? '',
        );
      });
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Self-service change password while logged in (separate from the
  /// logged-out OTP-based resetPassword() above).
  Future<ApiResponse<Map<String, dynamic>>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/portal/change-password'),
        headers: await _headers(),
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      return _handle<Map<String, dynamic>>(response, (data) => data ?? {});
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Set/change the WhatsApp number on one of the customer's own
  /// contracts. Pass an empty string to clear it (falls back to the
  /// contract's regular phone for WhatsApp sends).
  Future<ApiResponse<Map<String, dynamic>>> updateWhatsappPhone(
    int contractId,
    String whatsappPhone,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/portal/contracts/$contractId/whatsapp-phone'),
        headers: await _headers(),
        body: json.encode({'whatsapp_phone': whatsappPhone}),
      );
      return _handle<Map<String, dynamic>>(response, (data) => data ?? {});
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// Monthly payment totals across ALL of the customer's contracts --
  /// aggregated server-side (api/Portal::payment_history()), not summed
  /// from individual payment records client-side.
  Future<ApiResponse<List<MonthlyPaymentTotal>>> getPaymentHistory(
      {int months = 6}) async {
    try {
      final uri = Uri.parse('$_baseUrl/portal/payments/history')
          .replace(queryParameters: {'months': '$months'});
      final response = await http.get(uri, headers: await _headers());
      return _handle<List<MonthlyPaymentTotal>>(response, (data) {
        final list = (data['months'] as List?) ?? [];
        return list
            .map((e) => MonthlyPaymentTotal.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }
}
