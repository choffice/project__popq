class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.success,
    required this.data,
    required this.error,
  });

  factory ApiEnvelope.fromJson(
    Map<String, Object?> json,
    T Function(Object? value) decodeData,
  ) {
    final rawData = json['data'];
    final rawError = json['error'];

    return ApiEnvelope<T>(
      success: json['success'] == true,
      data: rawData == null ? null : decodeData(rawData),
      error: rawError is Map
          ? ApiError.fromJson(Map<String, Object?>.from(rawError))
          : null,
    );
  }

  final bool success;
  final T? data;
  final ApiError? error;
}

class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    this.path,
    this.details = const {},
  });

  factory ApiError.fromJson(Map<String, Object?> json) {
    final rawDetails = json['details'];
    return ApiError(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? '요청을 처리하지 못했습니다.',
      path: json['path'] as String?,
      details: rawDetails is Map
          ? Map<String, Object?>.from(rawDetails)
          : const {},
    );
  }

  final String code;
  final String message;
  final String? path;
  final Map<String, Object?> details;
}
