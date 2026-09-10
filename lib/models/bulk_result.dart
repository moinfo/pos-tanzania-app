// Shared response shape for every "act on several requests at once"
// endpoint (item approvals, transfer approvals, ...). Each processes ids
// independently server-side, so a batch always returns one BulkItemResult
// per id submitted -- a failure on one never throws away the rest.

class BulkItemResult {
  final int id;
  final bool success;
  final String? message;

  BulkItemResult({required this.id, required this.success, this.message});

  factory BulkItemResult.fromJson(Map<String, dynamic> json) {
    return BulkItemResult(
      id: _toInt(json['id']),
      success: json['success'] == true,
      message: json['message']?.toString(),
    );
  }
}

class BulkResult {
  final List<BulkItemResult> results;
  final int succeeded;
  final int total;

  BulkResult({required this.results, required this.succeeded, required this.total});

  factory BulkResult.fromJson(Map<String, dynamic> json) {
    return BulkResult(
      results: (json['results'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(BulkItemResult.fromJson)
              .toList() ??
          [],
      succeeded: _toInt(json['succeeded']),
      total: _toInt(json['total']),
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
