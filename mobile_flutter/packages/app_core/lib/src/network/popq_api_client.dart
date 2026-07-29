import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_envelope.dart';
import 'popq_failure.dart';

typedef AccessTokenReader = Future<String?> Function();
typedef ApiDataDecoder<T> = T Function(Object? value);

class PopqApiClient {
  PopqApiClient({
    required String baseUrl,
    required this.accessTokenReader,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _baseUri = Uri.parse(baseUrl),
       _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final AccessTokenReader accessTokenReader;
  final http.Client _httpClient;
  final Duration requestTimeout;

  Future<T> get<T>(
    String path, {
    Map<String, Object?> query = const {},
    required ApiDataDecoder<T> decode,
  }) {
    return _send(method: 'GET', path: path, query: query, decode: decode);
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    required ApiDataDecoder<T> decode,
  }) {
    return _send(method: 'POST', path: path, body: body, decode: decode);
  }

  Future<T> _send<T>({
    required String method,
    required String path,
    required ApiDataDecoder<T> decode,
    Map<String, Object?> query = const {},
    Object? body,
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
        'GET' =>
          await _httpClient.get(uri, headers: headers).timeout(requestTimeout),
        'POST' =>
          await _httpClient
              .post(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(requestTimeout),
        _ => throw ArgumentError.value(method, 'method'),
      };
    } on http.ClientException {
      throw const NetworkFailure();
    } on TimeoutException {
      throw const NetworkFailure('서버 응답이 지연되고 있습니다.');
    }

    final envelope = _decodeEnvelope(response, decode);
    if (response.statusCode == 401) {
      throw AuthenticationFailure(envelope.error?.message ?? '로그인이 필요합니다.');
    }
    final isSuccessfulStatus =
        response.statusCode >= 200 && response.statusCode < 300;
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
      throw const InvalidResponseFailure('응답 데이터가 비어 있습니다.');
    }
    return envelope.data as T;
  }

  ApiEnvelope<T> _decodeEnvelope<T>(
    http.Response response,
    ApiDataDecoder<T> decode,
  ) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
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

  Uri _buildUri(String path, Map<String, Object?> query) {
    final normalizedBase = _baseUri.toString().replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (query.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  void close() => _httpClient.close();
}
