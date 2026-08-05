import 'package:popq_app_core/popq_app_core.dart';

abstract interface class CustomerAuthRepository {
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  });

  Future<AuthSession> logIn({
    required String email,
    required String password,
  });

  Future<AuthSession> socialLogIn({
    required String provider,
    required String providerToken,
  });

  Future<String> findId({
    required String name,
    required String phone,
  });

  Future<void> verifyForPasswordReset({
    required String email,
    required String phone,
  });

  Future<void> resetPassword({
    required String email,
    required String phone,
    required String newPassword,
  });
}

class ApiCustomerAuthRepository implements CustomerAuthRepository {
  ApiCustomerAuthRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) {
    return _submit('/api/v1/auth/signup', {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'role': 'CUSTOMER',
    });
  }

  @override
  Future<AuthSession> logIn({
    required String email,
    required String password,
  }) {
    return _submit('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
  }

  @override
  Future<AuthSession> socialLogIn({
    required String provider,
    required String providerToken,
  }) {
    return _submit(
      '/api/v1/auth/social/login',
      {
        'provider': provider,
        'providerToken': providerToken,
        'role': 'CUSTOMER',
      },
    );
  }

  @override
  Future<String> findId({
    required String name,
    required String phone,
  }) async {
    final response = await _apiClient.post<Map<String, Object?>>(
      '/api/v1/auth/find-id',
      body: {'name': name, 'phone': phone},
      decode: (value) => Map<String, Object?>.from(value as Map),
    );
    return response['maskedEmail'] as String;
  }

  @override
  Future<void> verifyForPasswordReset({
    required String email,
    required String phone,
  }) async {
    await _apiClient.post<Map<String, Object?>>(
      '/api/v1/auth/password-reset/verify',
      body: {'email': email, 'phone': phone},
      decode: (value) => Map<String, Object?>.from(value as Map),
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String phone,
    required String newPassword,
  }) async {
    await _apiClient.post<Map<String, Object?>>(
      '/api/v1/auth/password-reset/confirm',
      body: {'email': email, 'phone': phone, 'newPassword': newPassword},
      decode: (value) => Map<String, Object?>.from(value as Map),
    );
  }

  Future<AuthSession> _submit(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _apiClient.post<Map<String, Object?>>(
      path,
      body: body,
      decode: (value) => Map<String, Object?>.from(value as Map),
    );

    final expiresIn = (response['expiresIn'] as num).toInt();
    return AuthSession(
      accessToken: response['accessToken'] as String,
      refreshToken: '',
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }
}

class MemoryCustomerAuthRepository implements CustomerAuthRepository {
  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    return _session();
  }

  @override
  Future<AuthSession> logIn({
    required String email,
    required String password,
  }) async {
    return _session();
  }

  @override
  Future<AuthSession> socialLogIn({
    required String provider,
    required String providerToken,
  }) async {
    return _session();
  }

  @override
  Future<String> findId({
    required String name,
    required String phone,
  }) async {
    return 'cu***@popq.test';
  }

  @override
  Future<void> verifyForPasswordReset({
    required String email,
    required String phone,
  }) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String phone,
    required String newPassword,
  }) async {}

  AuthSession _session() {
    return AuthSession(
      accessToken: 'memory-access',
      refreshToken: '',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }
}
