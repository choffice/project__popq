import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_envelope.dart';
import 'popq_failure.dart';

typedef AccessTokenReader = Future<String?> Function();
typedef RefreshTokenReader = Future<String?> Function();

typedef AuthSessionUpdater = Future<void> Function({
required String accessToken,
required String refreshToken,
required int expiresInSeconds,
});

typedef ApiDataDecoder<T> = T Function(Object? value);

class PopqApiClient {
  PopqApiClient({
    required String baseUrl,
    required this.accessTokenReader,
    this.refreshTokenReader,
    this.authSessionUpdater,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _baseUri = Uri.parse(baseUrl),
        _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;

  final AccessTokenReader accessTokenReader;
  final RefreshTokenReader? refreshTokenReader;
  final AuthSessionUpdater? authSessionUpdater;

  final http.Client _httpClient;
  final Duration requestTimeout;

  Future<bool>? _refreshInFlight;

  Future<T> get<T>(
      String path, {
        Map<String, Object?> query = const {},
        required ApiDataDecoder<T> decode,
      }) {
    return _send(
      method: 'GET',
      path: path,
      query: query,
      decode: decode,
    );
  }

  Future<T> post<T>(
      String path, {
        Object? body,
        required ApiDataDecoder<T> decode,
      }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      decode: decode,
    );
  }

  Future<T> put<T>(
      String path, {
        Object? body,
        required ApiDataDecoder<T> decode,
      }) {
    return _send(
      method: 'PUT',
      path: path,
      body: body,
      decode: decode,
    );
  }

  Future<T> patch<T>(
      String path, {
        Object? body,
        required ApiDataDecoder<T> decode,
      }) {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      decode: decode,
    );
  }

  Future<T> delete<T>(
      String path, {
        required ApiDataDecoder<T> decode,
      }) {
    return _send(
      method: 'DELETE',
      path: path,
      decode: decode,
    );
  }

  Future<T> postMultipartFile<T>(
      String path, {
        required String fieldName,
        required String filePath,
        required ApiDataDecoder<T> decode,
        Duration timeout = const Duration(seconds: 60),
      }) {
    return _postMultipartFile(
      path,
      fieldName: fieldName,
      filePath: filePath,
      decode: decode,
      timeout: timeout,
      allowRefresh: true,
    );
  }

  Future<T> _postMultipartFile<T>(
      String path, {
        required String fieldName,
        required String filePath,
        required ApiDataDecoder<T> decode,
        required Duration timeout,
        required bool allowRefresh,
      }) async {
    final uri = _buildUri(
      path,
      const <String, Object?>{},
    );

    final accessToken = await accessTokenReader();

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.headers.addAll(
      <String, String>{
        'Accept': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        filePath,
      ),
    );

    late http.Response response;

    try {
      final streamedResponse = await _httpClient
          .send(request)
          .timeout(timeout);

      response = await http.Response
          .fromStream(streamedResponse)
          .timeout(timeout);
    } on http.ClientException {
      throw const NetworkFailure();
    } on TimeoutException {
      throw const NetworkFailure(
        '이미지 업로드 응답이 지연되고 있습니다.',
      );
    }

    if (response.statusCode == 401 && allowRefresh) {
      final refreshed = await _refreshAccessToken();

      if (refreshed) {
        return _postMultipartFile(
          path,
          fieldName: fieldName,
          filePath: filePath,
          decode: decode,
          timeout: timeout,
          allowRefresh: false,
        );
      }
    }

    final envelope = _decodeEnvelope(
      response,
      decode,
    );

    if (response.statusCode == 401) {
      throw AuthenticationFailure(
        envelope.error?.message ?? '로그인이 필요합니다.',
      );
    }

    final isSuccessfulStatus =
        response.statusCode >= 200 &&
            response.statusCode < 300;

    if (!isSuccessfulStatus || !envelope.success) {
      final error = envelope.error;

      throw ApiRequestFailure(
        code: error?.code ?? 'HTTP_${response.statusCode}',
        statusCode: response.statusCode,
        message:
        error?.message ?? '이미지를 업로드하지 못했습니다.',
        details: error?.details ?? const {},
      );
    }

    if (envelope.data == null) {
      throw const InvalidResponseFailure(
        '이미지 업로드 응답이 비어 있습니다.',
      );
    }

    return envelope.data as T;
  }

  Future<T> _send<T>({
    required String method,
    required String path,
    required ApiDataDecoder<T> decode,
    Map<String, Object?> query = const {},
    Object? body,
    bool allowRefresh = true,
  }) async {
    final uri = _buildUri(path, query);

    final accessToken = await accessTokenReader();

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };

    late http.Response response;

    try {
      response = switch (method) {
        'GET' => await _httpClient
            .get(
          uri,
          headers: headers,
        )
            .timeout(requestTimeout),

        'POST' => await _httpClient
            .post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        )
            .timeout(requestTimeout),

        'PUT' => await _httpClient
            .put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        )
            .timeout(requestTimeout),

        'PATCH' => await _httpClient
            .patch(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        )
            .timeout(requestTimeout),

        'DELETE' => await _httpClient
            .delete(
          uri,
          headers: headers,
        )
            .timeout(requestTimeout),

        _ => throw ArgumentError.value(
          method,
          'method',
        ),
      };
    } on http.ClientException {
      throw const NetworkFailure();
    } on TimeoutException {
      throw const NetworkFailure(
        '서버 응답이 지연되고 있습니다.',
      );
    }

    if (response.statusCode == 401 &&
        allowRefresh &&
        path != '/api/v1/auth/refresh') {
      final refreshed = await _refreshAccessToken();

      if (refreshed) {
        return _send(
          method: method,
          path: path,
          query: query,
          body: body,
          decode: decode,
          allowRefresh: false,
        );
      }
    }

    final envelope = _decodeEnvelope(
      response,
      decode,
    );

    if (response.statusCode == 401) {
      throw AuthenticationFailure(
        envelope.error?.message ?? '로그인이 필요합니다.',
      );
    }

    final isSuccessfulStatus =
        response.statusCode >= 200 &&
            response.statusCode < 300;

    if (!isSuccessfulStatus || !envelope.success) {
      final error = envelope.error;

      throw ApiRequestFailure(
        code: error?.code ?? 'HTTP_${response.statusCode}',
        statusCode: response.statusCode,
        message: error?.message ?? '요청을 처리하지 못했습니다.',
        details: error?.details ?? const {},
      );
    }

    if (envelope.data == null) {
      throw const InvalidResponseFailure(
        '응답 데이터가 비어 있습니다.',
      );
    }

    return envelope.data as T;
  }
  Future<bool> refreshAccessToken() {
    return _refreshAccessToken();
  }
  Future<bool> _refreshAccessToken() async {
    final currentRefresh = _refreshInFlight;

    if (currentRefresh != null) {
      return currentRefresh;
    }

    final refreshFuture = _performRefresh();
    _refreshInFlight = refreshFuture;

    try {
      return await refreshFuture;
    } finally {
      if (identical(
        _refreshInFlight,
        refreshFuture,
      )) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _performRefresh() async {
    final readRefreshToken = refreshTokenReader;
    final updateSession = authSessionUpdater;

    if (readRefreshToken == null || updateSession == null) {
      return false;
    }

    final refreshToken = await readRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final uri = _buildUri(
      '/api/v1/auth/refresh',
      const <String, Object?>{},
    );

    late http.Response response;

    try {
      response = await _httpClient
          .post(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          <String, Object?>{
            'refreshToken': refreshToken,
          },
        ),
      )
          .timeout(requestTimeout);
    } on http.ClientException {
      throw const NetworkFailure();
    } on TimeoutException {
      throw const NetworkFailure(
        '로그인 갱신 응답이 지연되고 있습니다.',
      );
    }

    if (response.statusCode == 401 ||
        response.statusCode == 403) {
      return false;
    }

    final envelope =
    _decodeEnvelope<Map<String, Object?>>(
      response,
          (value) {
        return Map<String, Object?>.from(
          value as Map,
        );
      },
    );

    final isSuccessfulStatus =
        response.statusCode >= 200 &&
            response.statusCode < 300;

    if (!isSuccessfulStatus || !envelope.success) {
      final error = envelope.error;

      throw ApiRequestFailure(
        code: error?.code ?? 'HTTP_${response.statusCode}',
        statusCode: response.statusCode,
        message:
        error?.message ?? '로그인 정보를 갱신하지 못했습니다.',
        details: error?.details ?? const {},
      );
    }

    final data = envelope.data;

    if (data == null) {
      throw const InvalidResponseFailure(
        '토큰 갱신 응답이 비어 있습니다.',
      );
    }

    final accessToken = data['accessToken'];
    final newRefreshToken = data['refreshToken'];
    final expiresIn = data['expiresIn'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        newRefreshToken is! String ||
        newRefreshToken.isEmpty ||
        expiresIn is! num) {
      throw const InvalidResponseFailure(
        '토큰 갱신 응답 형식이 올바르지 않습니다.',
      );
    }

    await updateSession(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
      expiresInSeconds: expiresIn.toInt(),
    );

    return true;
  }

  ApiEnvelope<T> _decodeEnvelope<T>(
      http.Response response,
      ApiDataDecoder<T> decode,
      ) {
    try {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is! Map) {
        throw const InvalidResponseFailure();
      }

      return ApiEnvelope<T>.fromJson(
        Map<String, Object?>.from(decoded),
        decode,
      );
    } on FormatException {
      throw const InvalidResponseFailure();
    } on TypeError {
      throw const InvalidResponseFailure();
    }
  }

  Uri _buildUri(
      String path,
      Map<String, Object?> query,
      ) {
    final normalizedBase = _baseUri
        .toString()
        .replaceFirst(
      RegExp(r'/$'),
      '',
    );

    final normalizedPath =
    path.startsWith('/') ? path : '/$path';

    final uri = Uri.parse(
      '$normalizedBase$normalizedPath',
    );

    if (query.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: query.map(
            (key, value) => MapEntry(
          key,
          value?.toString(),
        ),
      ),
    );
  }

  void close() => _httpClient.close();
}