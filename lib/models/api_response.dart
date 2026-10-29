class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String message;
  final int? statusCode;

  /// True when the server accepted the request but did NOT apply it — the
  /// change is staged for someone else to approve (HTTP 202 + `pending`).
  /// Deliberately NOT a flavour of success: a caller that only checks
  /// isSuccess must never report the change as done, because it isn't.
  final bool isPending;

  /// Id of the staged change request, for callers that want to link to it.
  final int? pendingRequestId;

  /// The response body's `errors` object, when the server sent one (e.g. a
  /// 409 business-rule conflict like Lodge checkout's `errors.owing`, or a
  /// 400 validation map). Null for a plain error with no structured detail.
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.isSuccess,
    this.data,
    required this.message,
    this.statusCode,
    this.isPending = false,
    this.pendingRequestId,
    this.errors,
  });

  factory ApiResponse.success({T? data, String message = 'Success'}) {
    return ApiResponse(
      isSuccess: true,
      data: data,
      message: message,
      statusCode: 200,
    );
  }

  factory ApiResponse.error({
    required String message,
    int? statusCode,
    Map<String, dynamic>? errors,
  }) {
    return ApiResponse(
      isSuccess: false,
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }

  /// Accepted but not applied — awaiting approval. `data` is intentionally
  /// left null: the server sends back only an echo of what was submitted,
  /// not a saved record, so there is no real object to hand callers.
  factory ApiResponse.pending({
    required String message,
    int? requestId,
    int? statusCode,
  }) {
    return ApiResponse(
      isSuccess: false,
      message: message,
      statusCode: statusCode ?? 202,
      isPending: true,
      pendingRequestId: requestId,
    );
  }
}
