import 'package:popq_app_core/popq_app_core.dart';

abstract interface class CustomerAuthRepository {
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
  });

  Future<AuthSession> logIn({
    required String email,
    required String password,
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
    String? phone,
  }) {
    return _submit('/api/v1/auth/signup', {
      'email': email,
      'password': password,
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
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
    String? phone,
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

  AuthSession _session() {
    return AuthSession(
      accessToken: 'memory-access',
      refreshToken: '',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }
}
