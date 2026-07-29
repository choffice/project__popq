import 'package:popq_app_core/popq_app_core.dart';

class SellerStore {
  const SellerStore({
    required this.storeId,
    required this.storeType,
    required this.name,
    required this.status,
    required this.businessStatus,
    required this.myRole,
    this.description,
  });

  factory SellerStore.fromJson(Map<String, Object?> json) {
    return SellerStore(
      storeId: (json['storeId'] as num).toInt(),
      storeType: json['storeType'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      businessStatus: json['businessStatus'] as String,
      myRole: json['myRole'] as String,
    );
  }

  final int storeId;
  final String storeType;
  final String name;
  final String? description;
  final String status;
  final String businessStatus;
  final String myRole;
}

abstract interface class SellerStoreRepository {
  Future<List<SellerStore>> findAll();

  Future<SellerStore> createDevelopmentStore();
}

class ApiSellerStoreRepository implements SellerStoreRepository {
  ApiSellerStoreRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<List<SellerStore>> findAll() {
    return _apiClient.get(
      '/api/v1/seller/stores',
      decode: (value) => (value as List<Object?>)
          .map(
            (item) =>
                SellerStore.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
    );
  }

  @override
  Future<SellerStore> createDevelopmentStore() {
    return _apiClient.post(
      '/api/v1/seller/stores',
      body: {
        'storeType': 'LOCAL_STORE',
        'name': 'POPQ 개발 스토어',
        'description': '판매자 앱 개발용 자동 생성 스토어',
      },
      decode: (value) =>
          SellerStore.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }
}

class MemorySellerStoreRepository implements SellerStoreRepository {
  MemorySellerStoreRepository({List<SellerStore>? stores})
    : _stores =
          stores ??
          [
            const SellerStore(
              storeId: 1,
              storeType: 'LOCAL_STORE',
              name: '성수 커피 연구소',
              description: 'POPQ 메모리 스토어',
              status: 'ACTIVE',
              businessStatus: 'PRE_OPEN',
              myRole: 'OWNER',
            ),
          ];

  final List<SellerStore> _stores;

  @override
  Future<List<SellerStore>> findAll() async => List.unmodifiable(_stores);

  @override
  Future<SellerStore> createDevelopmentStore() async {
    final store = SellerStore(
      storeId: _stores.length + 1,
      storeType: 'LOCAL_STORE',
      name: 'POPQ 개발 스토어',
      description: '판매자 앱 개발용 자동 생성 스토어',
      status: 'ACTIVE',
      businessStatus: 'PRE_OPEN',
      myRole: 'OWNER',
    );
    _stores.add(store);
    return store;
  }
}
