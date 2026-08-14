import 'package:popq_app_core/popq_app_core.dart';

import '../permissions/customer_permission_gateway.dart';
import 'customer_store_schedule.dart';

class CustomerStore {
  const CustomerStore({
    required this.storeId,
    required this.storeType,
    required this.name,
    required this.businessStatus,
    required this.tags,
    this.description,
    this.eventName,
    this.address,
    this.detailAddress,
    this.representativeCategory,
    this.imageUrl,
    this.phone,
    this.latitude,
    this.longitude,
    this.openTime,
    this.closeTime,
    this.operationStartDate,
    this.operationEndDate,
    this.closedDays = const [],
    this.takeoutAvailable = true,
    this.dineInAvailable = true,
    this.orderAcceptingEnabled = true,
    this.distanceMeters,
    this.schedule,
  });

  factory CustomerStore.fromJson(
    Map<String, Object?> json, {
    String? imageBaseUrl,
  }) {
    return CustomerStore(
      storeId: (json['storeId'] as num).toInt(),
      storeType: json['storeType'] as String,
      name: json['name'] as String,
      eventName: json['eventName'] as String?,
      description: json['description'] as String?,
      businessStatus: json['businessStatus'] as String,
      address: json['address'] as String?,
      detailAddress: json['detailAddress'] as String?,
      representativeCategory: json['representativeCategory'] as String?,
      imageUrl: _resolveImageUrl(
        json['imageUrl'] as String?,
        imageBaseUrl,
      ),
      phone: json['phone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      openTime: json['openTime'] as String?,
      closeTime: json['closeTime'] as String?,
      operationStartDate: _readDate(json['operationStartDate']),
      operationEndDate: _readDate(json['operationEndDate']),
      closedDays: (json['closedDays'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      takeoutAvailable: json['takeoutAvailable'] as bool? ?? true,
      dineInAvailable: json['dineInAvailable'] as bool? ?? true,
      orderAcceptingEnabled:
          json['orderAcceptingEnabled'] as bool? ?? true,
      tags: (json['tags'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      schedule: CustomerStoreSchedule.fromJson(
        json['schedule'],
        legacyOpenTime: json['openTime'] as String?,
        legacyCloseTime: json['closeTime'] as String?,
        legacyClosedDays: (json['closedDays'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      ),
    );
  }

  final int storeId;
  final String storeType;
  final String name;
  final String? eventName;
  final String? description;
  final String businessStatus;
  final String? address;
  final String? detailAddress;
  final String? representativeCategory;
  final String? imageUrl;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? openTime;
  final String? closeTime;
  final DateTime? operationStartDate;
  final DateTime? operationEndDate;
  final List<String> closedDays;
  final bool takeoutAvailable;
  final bool dineInAvailable;
  final bool orderAcceptingEnabled;
  final List<String> tags;
  final int? distanceMeters;
  final CustomerStoreSchedule? schedule;

  CustomerStoreSchedule get resolvedSchedule =>
      schedule ?? CustomerStoreSchedule.legacy(
        openTime: openTime,
        closeTime: closeTime,
        closedDays: closedDays,
      );

  bool isOrderAccepting() {
    return businessStatus == 'OPEN' && orderAcceptingEnabled;
  }

  String get fullAddress {
    return <String?>[address, detailAddress]
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(' ');
  }
}

class StoreWalkingRoute {
  const StoreWalkingRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    this.landingUrl,
  });

  final int distanceMeters;
  final int durationSeconds;
  final String? landingUrl;

  int get durationMinutes {
    if (durationSeconds <= 0) {
      return 0;
    }

    return (durationSeconds / 60).ceil();
  }

  factory StoreWalkingRoute.fromJson(
      Map<String, dynamic> json,
      ) {
    return StoreWalkingRoute(
      distanceMeters: _readInt(
        json['distanceMeters'],
      ),
      durationSeconds: _readInt(
        json['durationSeconds'],
      ),
      landingUrl: _readNullableString(
        json['landingUrl'],
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  static String? _readNullableString(
      dynamic value,
      ) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}

abstract interface class StoreDiscoveryRepository {
  Future<List<CustomerStore>> search({
    String? query,
    String? tag,
    CustomerLocation? location,
    double? radiusKm,
  });

  Future<CustomerStore> findDetail(int storeId);

  Future<StoreWalkingRoute> findWalkingRoute({
    required int storeId,
    required CustomerLocation startLocation,
  });
}

class ApiStoreDiscoveryRepository implements StoreDiscoveryRepository {
  ApiStoreDiscoveryRepository(
    this._apiClient, {
    required this._imageBaseUrl,
  });

  final PopqApiClient _apiClient;
  final String _imageBaseUrl;

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
                imageBaseUrl: _imageBaseUrl,
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
      decode: (value) => CustomerStore.fromJson(
        Map<String, Object?>.from(value as Map),
        imageBaseUrl: _imageBaseUrl,
      ),
    );
  }

  @override
  Future<StoreWalkingRoute> findWalkingRoute({
    required int storeId,
    required CustomerLocation startLocation,
  }) {
    return _apiClient.get(
      '/api/v1/public/stores/$storeId/walking-route',
      query: {
        'startLatitude': startLocation.latitude,
        'startLongitude': startLocation.longitude,
      },
      decode: (value) => StoreWalkingRoute.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }
}

String? _resolveImageUrl(String? value, String? baseUrl) {
  final String path = value?.trim() ?? '';
  if (path.isEmpty) {
    return null;
  }

  final Uri? uri = Uri.tryParse(path);
  if (uri?.hasScheme == true) {
    return path;
  }

  final String base = baseUrl?.trim().replaceFirst(RegExp(r'/$'), '') ?? '';
  if (base.isEmpty) {
    return path;
  }

  return path.startsWith('/') ? '$base$path' : '$base/$path';
}

DateTime? _readDate(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.trim());
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
      latitude: 37.544700,
      longitude: 127.055700,
      tags: ['coffee', 'local'],
      distanceMeters: 280,
    ),
    CustomerStore(
      storeId: 2,
      storeType: 'EVENT_COMMERCE',
      name: '주말 디저트 마켓',
      eventName: '성수 디저트 페스타',
      description: '이번 주말에만 만나는 디저트 셀렉션',
      businessStatus: 'OPEN',
      address: '서울 성동구 성수이로',
      latitude: 37.545300,
      longitude: 127.052800,
      tags: ['dessert', 'event'],
      distanceMeters: 430,
    ),
    CustomerStore(
      storeId: 3,
      storeType: 'LOCAL_STORE',
      name: '연무장 수제버거',
      description: '직접 만든 패티와 소스로 준비하는 수제버거 매장',
      businessStatus: 'OPEN',
      address: '서울 성동구 연무장7길',
      latitude: 37.543800,
      longitude: 127.057500,
      tags: ['burger', 'local', 'food'],
      distanceMeters: 520,
    ),
    CustomerStore(
      storeId: 4,
      storeType: 'EVENT_COMMERCE',
      name: '성수 야외 플리마켓',
      eventName: '성수 주말 플리마켓',
      description: '소품과 디저트 브랜드가 함께하는 주말 야외 행사',
      businessStatus: 'OPEN',
      address: '서울 성동구 아차산로',
      latitude: 37.546000,
      longitude: 127.050900,
      tags: ['market', 'event', 'weekend'],
      distanceMeters: 670,
    ),
  ];

  final List<CustomerStore> _stores;

  @override
  Future<CustomerStore> findDetail(int storeId) async {
    return _stores.firstWhere((store) => store.storeId == storeId);
  }

  @override
  Future<StoreWalkingRoute> findWalkingRoute({
    required int storeId,
    required CustomerLocation startLocation,
  }) async {
    final store = _stores.firstWhere(
          (store) => store.storeId == storeId,
    );

    final distanceMeters = store.distanceMeters ?? 500;

    return StoreWalkingRoute(
      distanceMeters: distanceMeters,
      durationSeconds: (distanceMeters / 75).ceil() * 60,
    );
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
          (store.eventName?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (store.representativeCategory
                  ?.toLowerCase()
                  .contains(normalizedQuery) ??
              false) ||
          (store.address?.toLowerCase().contains(normalizedQuery) ?? false) ||
          store.tags.any(
            (String value) => value.trim().toLowerCase().contains(
              normalizedQuery,
            ),
          );
      final matchesTag = tag == null || tag.isEmpty || store.tags.contains(tag);
      return matchesQuery && matchesTag;
    }).toList();
  }
}
