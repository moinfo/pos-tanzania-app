// Transfer (/transfer) - CTN-to-PC same-location item conversion tool.
// Uses the same session-cookie auth as Industry/Stock Transfers, but
// addTransfer() has a DIFFERENT response contract from every other write
// endpoint in this app: no {success,message} JSON, just a redirect on
// success or a plain-text error body on failure.
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../models/transfer.dart';
import 'web_session_service.dart';

class TransferService {
  final WebSessionService _session = WebSessionService();

  WebSessionService get session => _session;

  Future<ApiResponse<TransferInventoryInfo>> getInventory({
    required int itemId,
    required int stockLocationId,
  }) async {
    return _postInventory('transfer/get_inventory', itemId, stockLocationId);
  }

  Future<ApiResponse<TransferInventoryInfo>> getInventoryTwo({
    required int itemId,
    required int stockLocationId,
  }) async {
    return _postInventory('transfer/get_inventory_two', itemId, stockLocationId);
  }

  Future<ApiResponse<TransferInventoryInfo>> _postInventory(
    String path,
    int itemId,
    int stockLocationId,
  ) async {
    try {
      final base = await _session.webBaseUrl;
      final result = await _session.postForm(Uri.parse('$base/$path'), {
        'id': itemId.toString(),
        'stock_id': stockLocationId.toString(),
      });
      return ApiResponse.success(data: TransferInventoryInfo.fromJson(result));
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// addTransfer() redirects (no body) on success and echoes a plain-text
  /// message on failure - not the {success,message} JSON every other write
  /// endpoint in this app uses, so this bypasses WebSessionService.postForm.
  Future<ApiResponse<void>> addTransfer({
    required int stockLocationId,
    required int parentItemId,
    required int childItemId,
    required double quantity,
    required double quantityReceived,
    required double ctnPrice,
    required double pcPrice,
    required double childCostPrice,
  }) async {
    try {
      final base = await _session.webBaseUrl;
      final uri = Uri.parse('$base/transfer/addTransfer');
      final headers = await _session.getHeaders();

      final response = await http.post(
        uri,
        headers: {...headers, 'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'stock_name': stockLocationId.toString(),
          'item_name': parentItemId.toString(),
          'item_name2': childItemId.toString(),
          'quantity': quantity.toString(),
          'quantity2': quantityReceived.toString(),
          'price': ctnPrice.toString(),
          'pricepc': pcPrice.toString(),
          'price2': childCostPrice.toString(),
          'receiving_type': 'TRANSFER',
        },
      );

      // Success = CI's redirect('transfer') - a 302/303 Location header.
      if (response.statusCode >= 300 && response.statusCode < 400) {
        return ApiResponse.success(message: 'Transfer completed');
      }

      final body = response.body.trim();
      if (body.isEmpty || body.startsWith('<') || body.contains('id="username"')) {
        // Empty body or an HTML page back = ambiguous; treat as session expiry
        // rather than silently claiming success.
        return ApiResponse.error(message: 'Web session expired', statusCode: 440);
      }
      return ApiResponse.error(message: body);
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  /// The Transfer Report table at the bottom of the page - server-rendered,
  /// no JSON endpoint, scraped from #datatable2.
  Future<ApiResponse<List<TransferHistoryRow>>> getTransferHistory(int stockLocationId) async {
    try {
      final base = await _session.webBaseUrl;
      final html = await _session
          .getHtml(Uri.parse('$base/transfer').replace(queryParameters: {}));
      return ApiResponse.success(data: _parseHistory(html));
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  List<TransferHistoryRow> _parseHistory(String html) {
    final tableMatch = RegExp(r'id="datatable2".*?<tbody>(.*?)</tbody>', dotAll: true).firstMatch(html);
    if (tableMatch == null) return [];

    final rows = <TransferHistoryRow>[];
    for (final rowMatch in RegExp(r'<tr>(.*?)</tr>', dotAll: true).allMatches(tableMatch.group(1)!)) {
      final cells = RegExp(r'<t[hd][^>]*>(.*?)</t[hd]>', dotAll: true)
          .allMatches(rowMatch.group(1) ?? '')
          .map((m) => (m.group(1) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim())
          .toList();
      if (cells.length < 6) continue;

      rows.add(TransferHistoryRow(
        itemName: cells[1],
        quantity: double.tryParse(cells[3]) ?? 0,
        total: double.tryParse(cells[5].replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
      ));
    }
    return rows;
  }
}
