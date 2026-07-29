import 'package:popq_app_core/popq_app_core.dart';

import '../permissions/customer_permission_gateway.dart';

class CustomerStore {
  const CustomerStore({
    required this.storeId,
    required this.storeType,
    required this.name,
    required this.businessStatus,
    required this.tags,
    this.description,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceMeters,
  });

  factory CustomerStore.fromJson(Map<String, Object?> json) {
    return CustomerStore(
      storeId: (json['storeId'] as num).toInt(),
      storeType: json['storeType'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      businessStatus: json['businessStatus'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      tags: (json['tags'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
    );
  }

  final int storeId;
  final String storeType;
  final String name;
  final String? description;
  final String businessStatus;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> tags;
  final int? distanceMeters;
}

abstract interface class StoreDiscoveryRepository {
  Future<List<CustomerStore>> search({
    String? query,
    String? tag,
    CustomerLocation? location,
    double? radiusKm,
  });

  Future<CustomerStore> findDetail(int storeId);
}

class ApiStoreDiscoveryRepository implements StoreDiscoveryRepository {
  ApiStoreDiscoveryRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<List<CustomerStore>> search({
    String? query,
    String? tag,
    CustomerLocation? location,
    double? radiusKm,
  }) {
    return _apiClient.get(
      '/api/v1/public/stores',
      query: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (location != null) 'latitude': location.latitude,
        if (location != null) 'longitude': location.longitude,
        if (location != null && radiusKm != null) 'radiusKm': radiusKm,
      },
      decode: (value) {
        final values = value as List<Object?>;
        return values
            .map(
              (item) => CustomerStore.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<CustomerStore> findDetail(int storeId) {
    return _apiClient.get(
      '/api/v1/public/stores/$storeId',
      decode: (value) =>
          CustomerStore.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }
}

class MemoryStoreDiscoveryRepository implements StoreDiscoveryRepository {
  MemoryStoreDiscoveryRepository({List<CustomerStore>? stores})
    : _stores = stores ?? sampleStores;

  static const sampleStores = [
    CustomerStore(
      storeId: 1,
      storeType: 'LOCAL_STORE',
      name: '성수 커피 연구소',
      description: '매일 새로운 원두를 소개하는 작은 로스터리',
      businessStatus: 'OPEN',
      address: '서울 성동구 연무장길',
      tags: ['coffee', 'local'],
      distanceMeters: 280,
    ),
    CustomerStore(
      storeId: 2,
      storeType: 'EVENT_COMMERCE',
      name: '주말 디저트 마켓',
      description: '이번 주말에만 만나는 디저트 셀렉션',
      businessStatus: 'OPEN',
      address: '서울 성동구 서울숲길',
      tags: ['dessert', 'event'],
      distanceMeters: 840,
    ),
  ];

  final List<CustomerStore> _stores;

  @override
  Future<CustomerStore> findDetail(int storeId) async {
    return _stores.firstWhere((store) => store.storeId == storeId);
  }

  @override
  Future<List<CustomerStore>> search({
    String? query,
    String? tag,
    CustomerLocation? location,
    double? radiusKm,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase();
    return _stores.where((store) {
      final matchesQuery =
          normalizedQuery == null ||
          normalizedQuery.isEmpty ||
          store.name.toLowerCase().contains(normalizedQuery) ||
          (store.description?.toLowerCase().contains(normalizedQuery) ?? false);
      final matchesTag = tag == null || tag.isEmpty || store.tags.contains(tag);
      return matchesQuery && matchesTag;
    }).toList();
  }
}
