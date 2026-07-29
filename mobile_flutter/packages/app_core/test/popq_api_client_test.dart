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

  test(
    'API client sends authenticated JSON PUT, PATCH and DELETE requests',
    () async {
      final requests = <http.Request>[];
      final apiClient = PopqApiClient(
        baseUrl: 'https://api.popq.test',
        accessTokenReader: () async => 'access-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'updated': true},
              'error': null,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await apiClient.put<Map<String, Object?>>(
        '/api/v1/customer/reviews/7',
        body: {'rating': 5},
        decode: (value) => Map<String, Object?>.from(value as Map),
      );
      await apiClient.delete<Map<String, Object?>>(
        '/api/v1/customer/reviews/7',
        decode: (value) => Map<String, Object?>.from(value as Map),
      );
      await apiClient.patch<Map<String, Object?>>(
        '/api/v1/seller/stores/1/products/7/availability',
        body: {'soldOut': true},
        decode: (value) => Map<String, Object?>.from(value as Map),
      );

      expect(requests[0].method, 'PUT');
      expect(requests[0].headers['Authorization'], 'Bearer access-token');
      expect(jsonDecode(requests[0].body), {'rating': 5});
      expect(requests[1].method, 'DELETE');
      expect(requests[1].headers['Authorization'], 'Bearer access-token');
      expect(requests[2].method, 'PATCH');
      expect(requests[2].headers['Authorization'], 'Bearer access-token');
      expect(jsonDecode(requests[2].body), {'soldOut': true});
    },
  );
}
