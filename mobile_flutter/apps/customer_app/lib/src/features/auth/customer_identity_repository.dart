import 'package:popq_app_core/popq_app_core.dart';

class CustomerIdentity {
  const CustomerIdentity({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
  });

  factory CustomerIdentity.fromJson(Map<String, Object?> json) {
    return CustomerIdentity(
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

  bool get isCustomer => role == 'CUSTOMER';
}

abstract interface class CustomerIdentityRepository {
  Future<CustomerIdentity> getCurrent();
}

class ApiCustomerIdentityRepository implements CustomerIdentityRepository {
  ApiCustomerIdentityRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<CustomerIdentity> getCurrent() {
    return _apiClient.get(
      '/api/v1/auth/me',
      decode: (value) =>
          CustomerIdentity.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }
}

class MemoryCustomerIdentityRepository implements CustomerIdentityRepository {
  const MemoryCustomerIdentityRepository({
    this.identity = const CustomerIdentity(
      userId: 1,
      email: 'customer@popq.test',
      name: 'POPQ 고객',
      role: 'CUSTOMER',
    ),
  });

  final CustomerIdentity identity;

  @override
  Future<CustomerIdentity> getCurrent() async => identity;
}
