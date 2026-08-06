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
    required String phone,
  });

  Future<SellerAuthResult> logIn({
    required String email,
    required String password,
  });

  Future<SellerAuthResult> socialLogIn({
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

  /// 현재 로그인된 계정의 탈퇴를 접수합니다.
  ///
  /// [confirmationPhrase]가 "{이름} / 탈퇴하겠습니다"와 정확히 일치하면
  /// 유예기간 없이 즉시 탈퇴되고, 그렇지 않으면(null 또는 생략) 7일의
  /// 유예기간을 두고 탈퇴 대기 상태가 됩니다.
  Future<void> withdraw({String? confirmationPhrase});
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
    required String phone,
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

  @override
  Future<SellerAuthResult> socialLogIn({
    required String provider,
    required String providerToken,
  }) async {
    return _result();
  }

  @override
  Future<String> findId({
    required String name,
    required String phone,
  }) async {
    return 'se***@popq.test';
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

  @override
  Future<void> withdraw({String? confirmationPhrase}) async {}

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
    required String phone,
  }) {
    return _submit('/api/v1/auth/signup', {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
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
      'role': 'SELLER',
    });
  }

  @override
  Future<SellerAuthResult> socialLogIn({
    required String provider,
    required String providerToken,
  }) {
    return _submit(
      '/api/v1/auth/social/login',
      {
        'provider': provider,
        'providerToken': providerToken,
        'role': 'SELLER',
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

  @override
  Future<void> withdraw({String? confirmationPhrase}) async {
    await _apiClient.post<Map<String, Object?>>(
      '/api/v1/auth/withdraw',
      body: confirmationPhrase == null
          ? null
          : {'confirmationPhrase': confirmationPhrase},
      decode: (value) => Map<String, Object?>.from(value as Map),
    );
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
