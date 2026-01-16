import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tra.dart';
import 'api_service.dart';

/// Result class for API operations
class TRAResult {
  final bool success;
  final String message;
  final int? id;

  TRAResult({required this.success, required this.message, this.id});
}

/// Result class for sales list
class TRASalesResult {
  final List<TRASale> sales;
  final TRASalesSummary? summary;
  final int totalCount;

  TRASalesResult({required this.sales, this.summary, required this.totalCount});
}

/// Result class for purchases/expenses list
class TRAPurchasesResult {
  final List<TRAPurchase> items;
  final TRAPurchasesSummary? summary;
  final int totalCount;

  TRAPurchasesResult({required this.items, this.summary, required this.totalCount});
}

/// Result class for last Z number
class TRALastZResult {
  final int lastZNumber;
  final int nextZNumber;

  TRALastZResult({required this.lastZNumber, required this.nextZNumber});
}

/// TRA (TRADE) Service for Tanzania Revenue Authority tax reporting
class TRAService {
  final ApiService _apiService = ApiService();

  /// Get TRA Dashboard summary
  Future<TRADashboard?> getDashboard({
    String? fromDate,
    String? toDate,
    int? efdId,
  }) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final queryParams = <String, String>{};
      if (fromDate != null) queryParams['from_date'] = fromDate;
      if (toDate != null) queryParams['to_date'] = toDate;
      if (efdId != null) queryParams['efd_id'] = efdId.toString();

      final uri = Uri.parse('$baseUrl/tra/dashboard').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('TRA Dashboard API Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return TRADashboard.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting TRA dashboard: $e');
      return null;
    }
  }

  /// Get EFD devices for current user
  Future<List<EFDDevice>> getEFDs() async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/tra/efds'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('TRA EFDs API Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final efds = data['data']['efds'] as List?;
          if (efds != null) {
            return efds.map((e) => EFDDevice.fromJson(e)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('Error getting EFDs: $e');
      return [];
    }
  }

  /// Get default EFD ID
  Future<int?> getDefaultEFDId() async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/tra/efds'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return data['data']['default_efd_id'] as int?;
        }
      }
      return null;
    } catch (e) {
      print('Error getting default EFD: $e');
      return null;
    }
  }

  // ==================== SALES ====================

  /// Get TRA Sales list
  Future<TRASalesResult> getSales({
    String? fromDate,
    String? toDate,
    int? efdId,
  }) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final queryParams = <String, String>{};
      if (fromDate != null) queryParams['from_date'] = fromDate;
      if (toDate != null) queryParams['to_date'] = toDate;
      if (efdId != null) queryParams['efd_id'] = efdId.toString();

      final uri = Uri.parse('$baseUrl/tra/sales').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final salesList = data['data']['sales'] as List?;
          final summaryData = data['data']['summary'];
          final totalCount = data['data']['total_count'] as int? ?? 0;

          return TRASalesResult(
            sales: salesList?.map((e) => TRASale.fromJson(e)).toList() ?? [],
            summary: summaryData != null ? TRASalesSummary.fromJson(summaryData) : null,
            totalCount: totalCount,
          );
        }
      }
      return TRASalesResult(sales: [], summary: null, totalCount: 0);
    } catch (e) {
      print('Error getting TRA sales: $e');
      return TRASalesResult(sales: [], summary: null, totalCount: 0);
    }
  }

  /// Get single TRA Sale
  Future<TRASale?> getSale(int id) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/tra/sales/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return TRASale.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting TRA sale: $e');
      return null;
    }
  }

  /// Create TRA Sale
  Future<TRAResult> createSale(TRASaleCreate sale) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final requestBody = json.encode(sale.toJson());

      // Check if request body is too large (>8MB can cause server issues)
      if (requestBody.length > 8 * 1024 * 1024) {
        return TRAResult(
          success: false,
          message: 'File is too large. Please use a smaller image.',
        );
      }

      final response = await http.post(
        Uri.parse('$baseUrl/tra/sales/create'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      // Check if response is HTML (server error page)
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        print('Server returned HTML error page: ${response.statusCode}');
        if (response.statusCode == 413) {
          return TRAResult(
            success: false,
            message: 'File is too large. Please use a smaller image.',
          );
        }
        return TRAResult(
          success: false,
          message: 'Server error (${response.statusCode}). Try without attaching a file.',
        );
      }

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(
          success: true,
          message: data['message'] ?? 'Sale created successfully',
          id: data['data']?['id'] as int?,
        );
      }
      return TRAResult(
        success: false,
        message: data['message'] ?? 'Failed to create sale',
      );
    } catch (e) {
      print('Error creating TRA sale: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  /// Update TRA Sale
  Future<TRAResult> updateSale(int id, TRASaleCreate sale) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final requestBody = json.encode(sale.toJson());

      final response = await http.put(
        Uri.parse('$baseUrl/tra/sales/update/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      // Check if response is HTML (server error page)
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html') ||
          response.body.trim().startsWith('<div')) {
        print('Server returned HTML error page: ${response.statusCode}');
        return TRAResult(
          success: false,
          message: 'Server error (${response.statusCode}). Please try again.',
        );
      }

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(success: true, message: data['message'] ?? 'Sale updated successfully');
      }
      return TRAResult(success: false, message: data['message'] ?? 'Failed to update sale');
    } catch (e) {
      print('Error updating TRA sale: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  /// Delete TRA Sale
  Future<TRAResult> deleteSale(int id) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.delete(
        Uri.parse('$baseUrl/tra/sales/delete/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(success: true, message: data['message'] ?? 'Sale deleted successfully');
      }
      return TRAResult(success: false, message: data['message'] ?? 'Failed to delete sale');
    } catch (e) {
      print('Error deleting TRA sale: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  /// Get last Z number for EFD
  Future<TRALastZResult> getLastZNumber(int efdId) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/tra/last-z-number/$efdId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return TRALastZResult(
            lastZNumber: data['data']['last_z_number'] as int? ?? 0,
            nextZNumber: data['data']['next_z_number'] as int? ?? 1,
          );
        }
      }
      return TRALastZResult(lastZNumber: 0, nextZNumber: 1);
    } catch (e) {
      print('Error getting last Z number: $e');
      return TRALastZResult(lastZNumber: 0, nextZNumber: 1);
    }
  }

  // ==================== PURCHASES ====================

  /// Get TRA Purchases list
  Future<TRAPurchasesResult> getPurchases({
    String? fromDate,
    String? toDate,
    int? efdId,
  }) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final queryParams = <String, String>{};
      if (fromDate != null) queryParams['from_date'] = fromDate;
      if (toDate != null) queryParams['to_date'] = toDate;
      if (efdId != null) queryParams['efd_id'] = efdId.toString();

      final uri = Uri.parse('$baseUrl/tra/purchases').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final purchasesList = data['data']['purchases'] as List?;
          final summaryData = data['data']['summary'];
          final totalCount = data['data']['total_count'] as int? ?? 0;

          return TRAPurchasesResult(
            items: purchasesList?.map((e) => TRAPurchase.fromJson(e)).toList() ?? [],
            summary: summaryData != null ? TRAPurchasesSummary.fromJson(summaryData) : null,
            totalCount: totalCount,
          );
        }
      }
      return TRAPurchasesResult(items: [], summary: null, totalCount: 0);
    } catch (e) {
      print('Error getting TRA purchases: $e');
      return TRAPurchasesResult(items: [], summary: null, totalCount: 0);
    }
  }

  /// Get single TRA Purchase
  Future<TRAPurchase?> getPurchase(int id) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/tra/purchases/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return TRAPurchase.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting TRA purchase: $e');
      return null;
    }
  }

  /// Create TRA Purchase
  Future<TRAResult> createPurchase(TRAPurchaseCreate purchase) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.post(
        Uri.parse('$baseUrl/tra/purchases/create'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(purchase.toJson()),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(
          success: true,
          message: data['message'] ?? 'Purchase created successfully',
          id: data['data']?['id'] as int?,
        );
      }
      return TRAResult(
        success: false,
        message: data['message'] ?? 'Failed to create purchase',
      );
    } catch (e) {
      print('Error creating TRA purchase: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  /// Update TRA Purchase
  Future<TRAResult> updatePurchase(int id, TRAPurchaseCreate purchase) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.put(
        Uri.parse('$baseUrl/tra/purchases/update/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(purchase.toJson()),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(success: true, message: data['message'] ?? 'Purchase updated successfully');
      }
      return TRAResult(success: false, message: data['message'] ?? 'Failed to update purchase');
    } catch (e) {
      print('Error updating TRA purchase: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  /// Delete TRA Purchase
  Future<TRAResult> deletePurchase(int id) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.delete(
        Uri.parse('$baseUrl/tra/purchases/delete/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(success: true, message: data['message'] ?? 'Purchase deleted successfully');
      }
      return TRAResult(success: false, message: data['message'] ?? 'Failed to delete purchase');
    } catch (e) {
      print('Error deleting TRA purchase: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  // ==================== EXPENSES ====================

  /// Get TRA Expenses list
  Future<TRAPurchasesResult> getExpenses({
    String? fromDate,
    String? toDate,
    int? efdId,
  }) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final queryParams = <String, String>{};
      if (fromDate != null) queryParams['from_date'] = fromDate;
      if (toDate != null) queryParams['to_date'] = toDate;
      if (efdId != null) queryParams['efd_id'] = efdId.toString();

      final uri = Uri.parse('$baseUrl/tra/expenses').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final expensesList = data['data']['expenses'] as List?;
          final summaryData = data['data']['summary'];
          final totalCount = data['data']['total_count'] as int? ?? 0;

          return TRAPurchasesResult(
            items: expensesList?.map((e) => TRAPurchase.fromJson(e)).toList() ?? [],
            summary: summaryData != null ? TRAPurchasesSummary.fromJson(summaryData) : null,
            totalCount: totalCount,
          );
        }
      }
      return TRAPurchasesResult(items: [], summary: null, totalCount: 0);
    } catch (e) {
      print('Error getting TRA expenses: $e');
      return TRAPurchasesResult(items: [], summary: null, totalCount: 0);
    }
  }

  /// Create TRA Expense
  Future<TRAResult> createExpense(TRAPurchaseCreate expense) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      // Ensure is_expense is set to YES
      final expenseData = expense.toJson();
      expenseData['is_expense'] = 'YES';

      final response = await http.post(
        Uri.parse('$baseUrl/tra/expenses/create'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(expenseData),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(
          success: true,
          message: data['message'] ?? 'Expense created successfully',
          id: data['data']?['id'] as int?,
        );
      }
      return TRAResult(
        success: false,
        message: data['message'] ?? 'Failed to create expense',
      );
    } catch (e) {
      print('Error creating TRA expense: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  /// Update TRA Expense
  Future<TRAResult> updateExpense(int id, TRAPurchaseCreate expense) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      // Ensure is_expense is set to YES
      final expenseData = expense.toJson();
      expenseData['is_expense'] = 'YES';

      final response = await http.put(
        Uri.parse('$baseUrl/tra/expenses/update/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(expenseData),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(success: true, message: data['message'] ?? 'Expense updated successfully');
      }
      return TRAResult(success: false, message: data['message'] ?? 'Failed to update expense');
    } catch (e) {
      print('Error updating TRA expense: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  /// Delete TRA Expense
  Future<TRAResult> deleteExpense(int id) async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.delete(
        Uri.parse('$baseUrl/tra/expenses/delete/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return TRAResult(success: true, message: data['message'] ?? 'Expense deleted successfully');
      }
      return TRAResult(success: false, message: data['message'] ?? 'Failed to delete expense');
    } catch (e) {
      print('Error deleting TRA expense: $e');
      return TRAResult(success: false, message: 'Error: $e');
    }
  }

  // ==================== DROPDOWNS ====================

  /// Get suppliers for dropdown
  Future<List<TRASupplier>> getSuppliers() async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/tra/suppliers'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final suppliers = data['data']['suppliers'] as List?;
          if (suppliers != null) {
            return suppliers.map((e) => TRASupplier.fromJson(e)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('Error getting suppliers: $e');
      return [];
    }
  }

  /// Get items for dropdown
  Future<List<TRAItem>> getItems() async {
    try {
      final baseUrl = ApiService.baseUrlSync;
      final token = await _apiService.getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/tra/items'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final items = data['data']['items'] as List?;
          if (items != null) {
            return items.map((e) => TRAItem.fromJson(e)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      print('Error getting items: $e');
      return [];
    }
  }
}
