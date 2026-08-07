import 'package:popq_app_core/popq_app_core.dart';

class SellerIdentity {
  const SellerIdentity({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
  });

  factory SellerIdentity.fromJson(Map<String, Object?> json) {
    return SellerIdentity(
      userId: (json['userId'] as num).toInt(),
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }

  final int userId;
  final String email;
  final String name;
  final String role;

  bool get isSeller => role == 'SELLER';
}

abstract interface class SellerIdentityRepository {
  Future<SellerIdentity> getCurrent();
}

class ApiSellerIdentityRepository implements SellerIdentityRepository {
  ApiSellerIdentityRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<SellerIdentity> getCurrent() {
    return _apiClient.get(
      '/api/v1/auth/me',
      decode: (value) =>
          SellerIdentity.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }
}

class MemorySellerIdentityRepository implements SellerIdentityRepository {
  const MemorySellerIdentityRepository({
    this.identity = const SellerIdentity(
      userId: 1,
      email: 'seller@popq.test',
      name: 'POPQ 판매자',
      role: 'SELLER',
    ),
  });

  final SellerIdentity identity;

  @override
  Future<SellerIdentity> getCurrent() async => identity;
}
