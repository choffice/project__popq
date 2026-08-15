import 'package:popq_app_core/popq_app_core.dart';

abstract interface class CustomerAuthRepository {
  Future<void> sendEmailVerificationCode({required String email});

  Future<String> verifyEmailCode({
    required String email,
    required String code,
  });

  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String emailVerificationToken,
  });

  Future<AuthSession> logIn({
    required String email,
    required String password,
  });

  Future<AuthSession> socialLogIn({
    required String provider,
    required String providerToken,
  });

  /// 이미 로그인된 계정에 소셜 로그인 수단을 추가로 연동합니다.
  Future<void> linkSocialAccount({
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

  /// 이미 CUSTOMER로 가입된 계정에 SELLER(판매자) 접근 권한을 추가로 연결합니다.
  Future<void> connectSellerAccess();

  /// 현재 로그인된 계정의 탈퇴를 접수합니다.
  ///
  /// [confirmationPhrase]가 "{이름} / 탈퇴하겠습니다"와 정확히 일치하면
  /// 유예기간 없이 즉시 탈퇴되고, 그렇지 않으면(null 또는 생략) 7일의
  /// 유예기간을 두고 탈퇴 대기 상태가 됩니다.
  Future<void> withdraw({String? confirmationPhrase});
}

class ApiCustomerAuthRepository implements CustomerAuthRepository {
  ApiCustomerAuthRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<void> sendEmailVerificationCode({required String email}) async {
    await _apiClient.post<Map<String, Object?>>(
      '/api/v1/auth/email-verification/send',
      body: {'email': email},
      decode: (value) => Map<String, Object?>.from(value as Map),
    );
  }

  @override
  Future<String> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post<Map<String, Object?>>(
      '/api/v1/auth/email-verification/confirm',
      body: {'email': email, 'code': code},
      decode: (value) => Map<String, Object?>.from(value as Map),
    );
    return response['verificationToken'] as String;
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String emailVerificationToken,
  }) {
    return _submit('/api/v1/auth/signup', {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'role': 'CUSTOMER',
      'emailVerificationToken': emailVerificationToken,
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
      'role': 'CUSTOMER',
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
  Future<void> linkSocialAccount({
    required String provider,
    required String providerToken,
  }) async {
    await _apiClient.post<Map<String, Object?>>(
      '/api/v1/users/me/social-accounts',
      body: {
        'provider': provider,
        'providerToken': providerToken,
      },
      decode: (value) => Map<String, Object?>.from(value as Map),
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
  Future<void> connectSellerAccess() async {
    await _apiClient.post<Map<String, Object?>>(
      '/api/v1/auth/connect-seller',
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

  Future<AuthSession> _submit(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _apiClient.post<Map<String, Object?>>(
      path,
      body: body,
      decode: (value) => Map<String, Object?>.from(value as Map),
    );

    final role = Map<String, Object?>.from(
      response['user'] as Map,
    )['role'];
    if (role != 'CUSTOMER') {
      throw StateError('customer role is required');
    }

    final expiresIn = (response['expiresIn'] as num).toInt();
    return AuthSession(
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }
}

class MemoryCustomerAuthRepository implements CustomerAuthRepository {
  @override
  Future<void> sendEmailVerificationCode({required String email}) async {}

  @override
  Future<String> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    return 'memory-email-verification-token';
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String emailVerificationToken,
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
  Future<void> linkSocialAccount({
    required String provider,
    required String providerToken,
  }) async {}

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

  @override
  Future<void> connectSellerAccess() async {}

  @override
  Future<void> withdraw({String? confirmationPhrase}) async {}

  AuthSession _session() {
    return AuthSession(
      accessToken: 'memory-access',
      refreshToken: '',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );
  }
}
