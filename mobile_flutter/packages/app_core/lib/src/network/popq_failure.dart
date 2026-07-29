sealed class PopqFailure implements Exception {
  const PopqFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class NetworkFailure extends PopqFailure {
  const NetworkFailure([super.message = '네트워크 연결을 확인해 주세요.']);
}

final class AuthenticationFailure extends PopqFailure {
  const AuthenticationFailure([super.message = '로그인이 필요합니다.']);
}

final class ApiRequestFailure extends PopqFailure {
  const ApiRequestFailure({
    required this.code,
    required this.statusCode,
    required String message,
    this.details = const {},
  }) : super(message);

  final String code;
  final int statusCode;
  final Map<String, Object?> details;
}

final class InvalidResponseFailure extends PopqFailure {
  const InvalidResponseFailure([super.message = '서버 응답을 해석하지 못했습니다.']);
}
