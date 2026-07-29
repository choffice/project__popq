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

  SellerStore copyWith({String? businessStatus}) {
    return SellerStore(
      storeId: storeId,
      storeType: storeType,
      name: name,
      description: description,
      status: status,
      businessStatus: businessStatus ?? this.businessStatus,
      myRole: myRole,
    );
  }
}

abstract interface class SellerStoreRepository {
  Future<List<SellerStore>> findAll();

  Future<SellerStore> createDevelopmentStore();

  Future<SellerStore> create({
    required String storeType,
    required String name,
    String? description,
    String? address,
  });

  Future<SellerStore> changeBusinessStatus(int storeId, String status);
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
    return create(
      storeType: 'LOCAL_STORE',
      name: 'POPQ 개발 스토어',
      description: '판매자 앱 개발용 자동 생성 스토어',
    );
  }

  @override
  Future<SellerStore> create({
    required String storeType,
    required String name,
    String? description,
    String? address,
  }) {
    return _apiClient.post(
      '/api/v1/seller/stores',
      body: {
        'storeType': storeType,
        'name': name,
        'description': description,
        'address': address,
        'tags': <String>[],
      },
      decode: (value) =>
          SellerStore.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }

  @override
  Future<SellerStore> changeBusinessStatus(int storeId, String status) {
    return _apiClient.patch(
      '/api/v1/seller/stores/$storeId/business-status',
      body: {'businessStatus': status},
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
    return create(
      storeType: 'LOCAL_STORE',
      name: 'POPQ 개발 스토어',
      description: '판매자 앱 개발용 자동 생성 스토어',
    );
  }

  @override
  Future<SellerStore> create({
    required String storeType,
    required String name,
    String? description,
    String? address,
  }) async {
    final store = SellerStore(
      storeId: _stores.length + 1,
      storeType: storeType,
      name: name,
      description: description,
      status: 'ACTIVE',
      businessStatus: 'PRE_OPEN',
      myRole: 'OWNER',
    );
    _stores.add(store);
    return store;
  }

  @override
  Future<SellerStore> changeBusinessStatus(int storeId, String status) async {
    final index = _stores.indexWhere((store) => store.storeId == storeId);
    if (index < 0) throw StateError('store not found');
    final store = _stores[index];
    if (store.myRole != 'OWNER' && store.myRole != 'MANAGER') {
      throw StateError('store manager role is required');
    }
    final updated = store.copyWith(businessStatus: status);
    _stores[index] = updated;
    return updated;
  }
}
