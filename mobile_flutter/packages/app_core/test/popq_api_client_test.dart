import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popq_app_core/popq_app_core.dart';

void main() {
  test('API client attaches the bearer token and decodes data', () async {
    final httpClient = MockClient((request) async {
      expect(request.url.toString(), 'https://api.popq.test/api/v1/auth/me');
      expect(request.headers['Authorization'], 'Bearer access-token');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'name': 'POPQ Customer'},
          'error': null,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final apiClient = PopqApiClient(
      baseUrl: 'https://api.popq.test',
      accessTokenReader: () async => 'access-token',
      httpClient: httpClient,
    );

    final name = await apiClient.get<String>(
      '/api/v1/auth/me',
      decode: (value) {
        final json = Map<String, Object?>.from(value! as Map);
        return json['name']! as String;
      },
    );

    expect(name, 'POPQ Customer');
  });

  test('API client maps unauthorized envelopes to authentication failure', () {
    final apiClient = PopqApiClient(
      baseUrl: 'https://api.popq.test',
      accessTokenReader: () async => null,
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'data': null,
            'error': {
              'code': 'AUTHENTICATION_REQUIRED',
              'message': '로그인이 필요합니다.',
            },
          }),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    expect(
      () => apiClient.get<Object>('/api/v1/auth/me', decode: (value) => value!),
      throwsA(isA<AuthenticationFailure>()),
    );
  });
}
