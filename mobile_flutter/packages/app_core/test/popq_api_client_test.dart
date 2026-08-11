import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popq_app_core/popq_app_core.dart';

void main() {
  test('API client attaches the bearer token and decodes data', () async {
    final httpClient = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://api.popq.test/api/v1/auth/me',
      );
      expect(
        request.headers['Authorization'],
        'Bearer access-token',
      );

      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'name': 'POPQ Customer'},
          'error': null,
        }),
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
        },
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
        final json = Map<String, Object?>.from(
          value! as Map,
        );

        return json['name']! as String;
      },
    );

    expect(name, 'POPQ Customer');
  });

  test(
    'API client maps unauthorized envelopes to authentication failure',
        () {
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
            headers: {
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      expect(
            () => apiClient.get<Object>(
          '/api/v1/auth/me',
          decode: (value) => value!,
        ),
        throwsA(
          isA<AuthenticationFailure>(),
        ),
      );
    },
  );

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
            headers: {
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      await apiClient.put<Map<String, Object?>>(
        '/api/v1/customer/reviews/7',
        body: {'rating': 5},
        decode: (value) {
          return Map<String, Object?>.from(
            value as Map,
          );
        },
      );

      await apiClient.delete<Map<String, Object?>>(
        '/api/v1/customer/reviews/7',
        decode: (value) {
          return Map<String, Object?>.from(
            value as Map,
          );
        },
      );

      await apiClient.patch<Map<String, Object?>>(
        '/api/v1/seller/stores/1/products/7/availability',
        body: {'soldOut': true},
        decode: (value) {
          return Map<String, Object?>.from(
            value as Map,
          );
        },
      );

      expect(
        requests[0].method,
        'PUT',
      );
      expect(
        requests[0].headers['Authorization'],
        'Bearer access-token',
      );
      expect(
        jsonDecode(requests[0].body),
        {'rating': 5},
      );

      expect(
        requests[1].method,
        'DELETE',
      );
      expect(
        requests[1].headers['Authorization'],
        'Bearer access-token',
      );

      expect(
        requests[2].method,
        'PATCH',
      );
      expect(
        requests[2].headers['Authorization'],
        'Bearer access-token',
      );
      expect(
        jsonDecode(requests[2].body),
        {'soldOut': true},
      );
    },
  );

  test(
    'API client refreshes the token on 401 and retries the request once',
        () async {
      var storedAccessToken = 'expired-access-token';
      var storedRefreshToken = 'refresh-token-1';

      var apiRequestCount = 0;
      var refreshRequestCount = 0;

      final apiClient = PopqApiClient(
        baseUrl: 'https://api.popq.test',

        accessTokenReader: () async {
          return storedAccessToken;
        },

        refreshTokenReader: () async {
          return storedRefreshToken;
        },

        authSessionUpdater: ({
          required String accessToken,
          required String refreshToken,
          required int expiresInSeconds,
        }) async {
          storedAccessToken = accessToken;
          storedRefreshToken = refreshToken;

          expect(
            expiresInSeconds,
            3600,
          );
        },

        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/auth/refresh') {
            refreshRequestCount++;

            expect(
              request.method,
              'POST',
            );

            final body = Map<String, Object?>.from(
              jsonDecode(request.body) as Map,
            );

            expect(
              body['refreshToken'],
              'refresh-token-1',
            );

            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'accessToken': 'new-access-token',
                  'refreshToken': 'refresh-token-2',
                  'tokenType': 'Bearer',
                  'expiresIn': 3600,
                },
                'error': null,
              }),
              200,
              headers: {
                'content-type':
                'application/json; charset=utf-8',
              },
            );
          }

          apiRequestCount++;

          if (apiRequestCount == 1) {
            expect(
              request.headers['Authorization'],
              'Bearer expired-access-token',
            );

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
              headers: {
                'content-type':
                'application/json; charset=utf-8',
              },
            );
          }

          expect(
            request.headers['Authorization'],
            'Bearer new-access-token',
          );

          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'name': 'POPQ Customer',
              },
              'error': null,
            }),
            200,
            headers: {
              'content-type':
              'application/json; charset=utf-8',
            },
          );
        }),
      );

      final name = await apiClient.get<String>(
        '/api/v1/auth/me',
        decode: (value) {
          final json = Map<String, Object?>.from(
            value as Map,
          );

          return json['name'] as String;
        },
      );

      expect(
        name,
        'POPQ Customer',
      );

      expect(
        refreshRequestCount,
        1,
      );

      expect(
        apiRequestCount,
        2,
      );

      expect(
        storedAccessToken,
        'new-access-token',
      );

      expect(
        storedRefreshToken,
        'refresh-token-2',
      );
    },
  );
}