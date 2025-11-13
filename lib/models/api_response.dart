class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String message;
  final int? statusCode;

  ApiResponse({
    required this.isSuccess,
    this.data,
    required this.message,
    this.statusCode,
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
  }) {
    return ApiResponse(
      isSuccess: false,
      message: message,
      statusCode: statusCode,
    );
  }
}
