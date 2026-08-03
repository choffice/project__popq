import 'package:popq_app_core/popq_app_core.dart';

import 'seller_identity_repository.dart';

class SellerAuthResult {
  const SellerAuthResult({required this.session, required this.identity});

  final AuthSession session;
  final SellerIdentity identity;
}

abstract interface class SellerAuthRepository {
  Future<SellerAuthResult> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
  });

  Future<SellerAuthResult> logIn({
    required String email,
    required String password,
  });
}

class MemorySellerAuthRepository implements SellerAuthRepository {
  MemorySellerAuthRepository({
    this.identity = const SellerIdentity(
      userId: 1,
      email: 'seller@popq.test',
      name: 'POPQ 판매자',
      role: 'SELLER',
    ),
  });

  final SellerIdentity identity;

  @override
  Future<SellerAuthResult> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    return _result();
  }

  @override
  Future<SellerAuthResult> logIn({
    required String email,
    required String password,
  }) async {
    return _result();
  }

  SellerAuthResult _result() {
    return SellerAuthResult(
      session: AuthSession(
        accessToken: 'memory-access',
        refreshToken: '',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      identity: identity,
    );
  }
}

class ApiSellerAuthRepository implements SellerAuthRepository {
  ApiSellerAuthRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<SellerAuthResult> signUp({
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
      'role': 'SELLER',
    });
  }

  @override
  Future<SellerAuthResult> logIn({
    required String email,
    required String password,
  }) {
    return _submit('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<SellerAuthResult> _submit(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _apiClient.post<Map<String, Object?>>(
      path,
      body: body,
      decode: (value) => Map<String, Object?>.from(value as Map),
    );

    final identity = SellerIdentity.fromJson(
      Map<String, Object?>.from(response['user'] as Map),
    );
    if (!identity.isSeller) {
      throw StateError('seller role is required');
    }

    final expiresIn = (response['expiresIn'] as num).toInt();
    final session = AuthSession(
      accessToken: response['accessToken'] as String,
      refreshToken: '',
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );

    return SellerAuthResult(session: session, identity: identity);
  }
}
