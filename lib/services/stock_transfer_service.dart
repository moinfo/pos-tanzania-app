// Stock Transfers (ARG Sparkles only). Uses the same session-cookie auth as
// Industry (WebSessionService) since Stock_transfers.php has no JWT API.
// Item and stock-location pickers reuse the app's existing JWT ApiService
// methods (getItems/getAllStockLocations) rather than scraping those too.
import '../models/api_response.dart';
import '../models/stock_transfer.dart';
import 'web_session_service.dart';

class StockTransferService {
  final WebSessionService _session = WebSessionService();

  WebSessionService get session => _session;

  Future<ApiResponse<StockTransfersPage>> getTransfers({String? startDate, String? endDate}) async {
    try {
      final base = await _session.webBaseUrl;
      final uri = Uri.parse('$base/stock_transfers').replace(queryParameters: {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      });
      final html = await _session.getHtml(uri);
      return ApiResponse.success(data: _parseHtml(html));
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<List<BatchItem>>> getBatchItems(int batchId) async {
    try {
      final base = await _session.webBaseUrl;
      final list = await _session.getJsonList(Uri.parse('$base/stock_transfers/batch_items/$batchId'));
      return ApiResponse.success(
        data: list.map((e) => BatchItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> issueBatch({
    required List<ShipmentLine> items,
    required int fromLocationId,
    required int toLocationId,
    String note = '',
  }) async {
    final base = await _session.webBaseUrl;
    final itemsJson = items
        .map((i) => '{"item_id":${i.itemId},"quantity":${i.quantity}}')
        .join(',');
    return _post(Uri.parse('$base/stock_transfers/issue_batch'), {
      'items': '[$itemsJson]',
      'from_location_id': fromLocationId.toString(),
      'to_location_id': toLocationId.toString(),
      'note': note,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> confirmBatch(int batchId) async {
    final base = await _session.webBaseUrl;
    return _post(Uri.parse('$base/stock_transfers/confirm_batch/$batchId'), {});
  }

  Future<ApiResponse<Map<String, dynamic>>> cancelBatch(int batchId) async {
    final base = await _session.webBaseUrl;
    return _post(Uri.parse('$base/stock_transfers/cancel_batch/$batchId'), {});
  }

  Future<ApiResponse<Map<String, dynamic>>> issueTransfer({
    required int itemId,
    required double quantity,
    required int fromLocationId,
    required int toLocationId,
    String note = '',
  }) async {
    final base = await _session.webBaseUrl;
    return _post(Uri.parse('$base/stock_transfers/issue'), {
      'item_id': itemId.toString(),
      'quantity': quantity.toString(),
      'from_location_id': fromLocationId.toString(),
      'to_location_id': toLocationId.toString(),
      'note': note,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> confirmTransfer(int transferId) async {
    final base = await _session.webBaseUrl;
    return _post(Uri.parse('$base/stock_transfers/confirm/$transferId'), {});
  }

  Future<ApiResponse<Map<String, dynamic>>> cancelTransfer(int transferId) async {
    final base = await _session.webBaseUrl;
    return _post(Uri.parse('$base/stock_transfers/cancel/$transferId'), {});
  }

  Future<ApiResponse<Map<String, dynamic>>> _post(Uri uri, Map<String, String> fields) async {
    try {
      final result = await _session.postForm(uri, fields);
      return ApiResponse.success(data: result, message: result['message']?.toString() ?? 'Success');
    } on WebActionFailedException catch (e) {
      return ApiResponse.error(message: e.message);
    } on WebSessionExpiredException {
      return ApiResponse.error(message: 'Web session expired', statusCode: 440);
    } catch (e) {
      return ApiResponse.error(message: 'Connection error: $e');
    }
  }

  StockTransfersPage _parseHtml(String html) {
    return StockTransfersPage(
      pendingBatches: _parsePendingBatches(html),
      pending: _parsePendingTransfers(html),
      history: _parseHistory(html),
    );
  }

  List<PendingBatch> _parsePendingBatches(String html) {
    // Anchored on the glyphicon-time icon in that card's header - a stable
    // CSS class, unlike the *translated* lang-line text next to it.
    final tableMatch = RegExp(
      r'glyphicon-time.*?<tbody>(.*?)</tbody>',
      dotAll: true,
    ).firstMatch(html);
    if (tableMatch == null) return [];

    final batches = <PendingBatch>[];
    // Each shipment spans TWO <tr> (the row itself, then a hidden detail
    // row) - only match rows that actually contain a batch id ("#123").
    for (final rowMatch in RegExp(r'<tr>(.*?)</tr>', dotAll: true).allMatches(tableMatch.group(1)!)) {
      final row = rowMatch.group(1) ?? '';
      final idMatch = RegExp(r'>#(\d+)<').firstMatch(row);
      if (idMatch == null) continue;

      final cells = _extractCells(row);
      if (cells.length < 6) continue;

      batches.add(PendingBatch(
        batchId: int.tryParse(idMatch.group(1)!) ?? 0,
        fromLocationName: cells[1],
        toLocationName: cells[2],
        itemCount: int.tryParse(RegExp(r'\d+').firstMatch(cells[3])?.group(0) ?? '0') ?? 0,
        issuedByName: cells[4],
        issuedDate: cells[5],
        note: cells.length > 6 ? cells[6] : '',
      ));
    }
    return batches;
  }

  List<PendingTransfer> _parsePendingTransfers(String html) {
    // Anchored on the glyphicon-transfer icon in that card's header - a
    // stable CSS class, unlike the *translated* lang-line text next to it.
    final tableMatch = RegExp(
      r'glyphicon-transfer.*?<tbody>(.*?)</tbody>',
      dotAll: true,
    ).firstMatch(html);
    if (tableMatch == null) return [];

    final rows = <PendingTransfer>[];
    for (final rowMatch in RegExp(r'<tr>(.*?)</tr>', dotAll: true).allMatches(tableMatch.group(1)!)) {
      final row = rowMatch.group(1) ?? '';
      final cells = _extractCells(row);
      if (cells.length < 7) continue;

      final idMatch = RegExp(r'data-id="(\d+)"').firstMatch(row);

      rows.add(PendingTransfer(
        transferId: idMatch != null ? int.tryParse(idMatch.group(1)!) : null,
        itemName: cells[0],
        quantity: cells[1],
        fromLocationName: cells[2],
        toLocationName: cells[3],
        issuedByName: cells[4],
        issuedDate: cells[5],
        note: cells[6],
      ));
    }
    return rows;
  }

  List<TransferHistoryRow> _parseHistory(String html) {
    // Anchored on the glyphicon-list-alt icon in that card's header - a
    // stable CSS class, unlike the *translated* lang-line text next to it.
    final tableMatch = RegExp(
      r'glyphicon-list-alt.*?<tbody>(.*?)</tbody>',
      dotAll: true,
    ).firstMatch(html);
    if (tableMatch == null) return [];

    final rows = <TransferHistoryRow>[];
    for (final rowMatch in RegExp(r'<tr>(.*?)</tr>', dotAll: true).allMatches(tableMatch.group(1)!)) {
      final cells = _extractCells(rowMatch.group(1) ?? '');
      if (cells.length < 9) continue;

      rows.add(TransferHistoryRow(
        itemName: cells[0],
        quantity: cells[1],
        fromLocationName: cells[2],
        toLocationName: cells[3],
        status: cells[4],
        issuedByName: cells[5],
        issuedDate: cells[6],
        confirmedByName: cells[7],
        confirmedDate: cells[8],
      ));
    }
    return rows;
  }

  List<String> _extractCells(String row) {
    return RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true).allMatches(row).map((m) {
      final raw = m.group(1) ?? '';
      final textOnly = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      return _decodeHtmlEntities(textOnly);
    }).toList();
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
