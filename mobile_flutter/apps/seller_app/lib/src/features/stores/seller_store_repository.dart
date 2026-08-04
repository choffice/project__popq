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
    this.address,
    this.detailAddress,
    this.representativeCategory,
    this.imageUrl,
    this.phone,
    this.latitude,
    this.longitude,
    this.openTime,
    this.closeTime,
    this.closedDays = const [],
    this.takeoutAvailable = true,
    this.dineInAvailable = true,
    this.orderAcceptingEnabled = true,
    this.tags = const [],
  });

  factory SellerStore.fromJson(Map<String, Object?> json) {
    return SellerStore(
      storeId: (json['storeId'] as num).toInt(),
      storeType: json['storeType'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      detailAddress: json['detailAddress'] as String?,
      representativeCategory:
      json['representativeCategory'] as String?,
      imageUrl: json['imageUrl'] as String?,
      phone: json['phone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      openTime: json['openTime'] as String?,
      closeTime: json['closeTime'] as String?,
      closedDays: _readStringList(
        json['closedDays'],
      ),
      takeoutAvailable:
      json['takeoutAvailable'] as bool? ?? true,
      dineInAvailable:
      json['dineInAvailable'] as bool? ?? true,
      orderAcceptingEnabled:
      json['orderAcceptingEnabled'] as bool? ?? true,
      tags: _readStringList(
        json['tags'],
      ),
      status: json['status'] as String,
      businessStatus: json['businessStatus'] as String,
      myRole: json['myRole'] as String,
    );
  }

  final int storeId;
  final String storeType;
  final String name;
  final String? description;
  final String? address;
  final String? detailAddress;
  final String? representativeCategory;
  final String? imageUrl;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? openTime;
  final String? closeTime;
  final List<String> closedDays;
  final bool takeoutAvailable;
  final bool dineInAvailable;
  final bool orderAcceptingEnabled;
  final List<String> tags;
  final String status;
  final String businessStatus;
  final String myRole;

  SellerStore copyWith({
    String? name,
    String? description,
    String? address,
    String? detailAddress,
    String? representativeCategory,
    String? imageUrl,
    String? phone,
    double? latitude,
    double? longitude,
    String? openTime,
    String? closeTime,
    List<String>? closedDays,
    bool? takeoutAvailable,
    bool? dineInAvailable,
    bool? orderAcceptingEnabled,
    List<String>? tags,
    String? businessStatus,
  }) {
    return SellerStore(
      storeId: storeId,
      storeType: storeType,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      detailAddress:
      detailAddress ?? this.detailAddress,
      representativeCategory:
      representativeCategory ??
          this.representativeCategory,
      imageUrl: imageUrl ?? this.imageUrl,
      phone: phone ?? this.phone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      closedDays: closedDays ?? this.closedDays,
      takeoutAvailable:
      takeoutAvailable ?? this.takeoutAvailable,
      dineInAvailable:
      dineInAvailable ?? this.dineInAvailable,
      orderAcceptingEnabled:
      orderAcceptingEnabled ??
          this.orderAcceptingEnabled,
      tags: tags ?? this.tags,
      status: status,
      businessStatus:
      businessStatus ?? this.businessStatus,
      myRole: myRole,
    );
  }
}

class SellerAddressSearchResult {
  const SellerAddressSearchResult({
    required this.addressName,
    required this.latitude,
    required this.longitude,
    this.roadAddressName,
    this.jibunAddressName,
    this.zoneNo,
  });

  factory SellerAddressSearchResult.fromJson(
      Map<String, Object?> json,
      ) {
    final Object? latitudeValue =
    json['latitude'];

    final Object? longitudeValue =
    json['longitude'];

    if (latitudeValue is! num ||
        longitudeValue is! num) {
      throw const InvalidResponseFailure(
        '주소 검색 결과의 좌표가 올바르지 않습니다.',
      );
    }

    final String addressName =
        json['addressName']?.toString().trim() ??
            '';

    if (addressName.isEmpty) {
      throw const InvalidResponseFailure(
        '주소 검색 결과에 주소가 없습니다.',
      );
    }

    return SellerAddressSearchResult(
      addressName: addressName,
      roadAddressName:
      _readNullableString(
        json['roadAddressName'],
      ),
      jibunAddressName:
      _readNullableString(
        json['jibunAddressName'],
      ),
      zoneNo: _readNullableString(
        json['zoneNo'],
      ),
      latitude:
      latitudeValue.toDouble(),
      longitude:
      longitudeValue.toDouble(),
    );
  }

  final String addressName;
  final String? roadAddressName;
  final String? jibunAddressName;
  final String? zoneNo;

  final double latitude;
  final double longitude;
}

abstract interface class SellerStoreRepository {
  Future<List<SellerStore>> findAll();

  Future<List<SellerAddressSearchResult>>
  searchAddresses(
      String query,
      );

  Future<SellerStore> findOne(
      int storeId,
      );

  Future<SellerStore> createDevelopmentStore();

  Future<String> uploadRepresentativeImage(
      String filePath,
      );

  Future<SellerStore> create({
    required String storeType,
    required String name,
    String? description,
    String? address,
    String? detailAddress,
    String? representativeCategory,
    String? imageUrl,
    String? phone,
    double? latitude,
    double? longitude,
    String? openTime,
    String? closeTime,
    List<String> closedDays = const [],
    bool takeoutAvailable = true,
    bool dineInAvailable = true,
    bool orderAcceptingEnabled = true,
    List<String> tags = const [],
  });

  Future<SellerStore> changeBusinessStatus(
      int storeId,
      String status,
      );

  Future<SellerStore> update(
      int storeId, {
        required String name,
        String? description,
        String? address,
        String? detailAddress,
        String? representativeCategory,
        String? imageUrl,
        String? phone,
        double? latitude,
        double? longitude,
        String? openTime,
        String? closeTime,
        List<String>? closedDays,
        bool? takeoutAvailable,
        bool? dineInAvailable,
        bool? orderAcceptingEnabled,
        List<String> tags = const [],
      });

  Future<void> delete(
      int storeId,
      );
}

class ApiSellerStoreRepository
    implements SellerStoreRepository {
  ApiSellerStoreRepository(
      this._apiClient,
      );

  final PopqApiClient _apiClient;

  @override
  Future<List<SellerStore>> findAll() {
    return _apiClient.get(
      '/api/v1/seller/stores',
      decode: (Object? value) {
        return (value as List<Object?>)
            .map(
              (Object? item) =>
              SellerStore.fromJson(
                Map<String, Object?>.from(
                  item as Map,
                ),
              ),
        )
            .toList();
      },
    );
  }

  @override
  Future<List<SellerAddressSearchResult>>
  searchAddresses(
      String query,
      ) {
    return _apiClient.get<
        List<SellerAddressSearchResult>>(
      '/api/v1/seller/location/addresses',
      query: <String, Object?>{
        'query': query,
      },
      decode: (Object? value) {
        if (value is! List) {
          throw const InvalidResponseFailure(
            '주소 검색 응답 형식이 올바르지 않습니다.',
          );
        }

        return value
            .map(
              (Object? item) {
            if (item is! Map) {
              throw const InvalidResponseFailure(
                '주소 검색 결과 형식이 올바르지 않습니다.',
              );
            }

            return SellerAddressSearchResult
                .fromJson(
              Map<String, Object?>.from(
                item,
              ),
            );
          },
        )
            .toList(
          growable: false,
        );
      },
    );
  }

  @override
  Future<SellerStore> findOne(
      int storeId,
      ) {
    return _apiClient.get(
      '/api/v1/seller/stores/$storeId',
      decode: (Object? value) {
        return SellerStore.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
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
  Future<String> uploadRepresentativeImage(
      String filePath,
      ) {
    return _apiClient.postMultipartFile<String>(
      '/api/v1/seller/store-images',
      fieldName: 'file',
      filePath: filePath,
      decode: (Object? value) {
        final Map<String, Object?> json =
        Map<String, Object?>.from(
          value as Map,
        );

        final Object? imageUrl =
        json['imageUrl'];

        if (imageUrl is! String ||
            imageUrl.trim().isEmpty) {
          throw const InvalidResponseFailure(
            '업로드된 이미지 URL이 없습니다.',
          );
        }

        return imageUrl;
      },
    );
  }

  @override
  Future<SellerStore> create({
    required String storeType,
    required String name,
    String? description,
    String? address,
    String? detailAddress,
    String? representativeCategory,
    String? imageUrl,
    String? phone,
    double? latitude,
    double? longitude,
    String? openTime,
    String? closeTime,
    List<String> closedDays = const [],
    bool takeoutAvailable = true,
    bool dineInAvailable = true,
    bool orderAcceptingEnabled = true,
    List<String> tags = const [],
  }) {
    return _apiClient.post(
      '/api/v1/seller/stores',
      body: {
        'storeType': storeType,
        'name': name,
        'description': description,
        'address': address,
        'detailAddress': detailAddress,
        'representativeCategory':
        representativeCategory,
        'imageUrl': imageUrl,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'openTime': openTime,
        'closeTime': closeTime,
        'closedDays': closedDays,
        'takeoutAvailable': takeoutAvailable,
        'dineInAvailable': dineInAvailable,
        'orderAcceptingEnabled':
        orderAcceptingEnabled,
        'tags': tags,
      },
      decode: (Object? value) {
        return SellerStore.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<SellerStore> changeBusinessStatus(
      int storeId,
      String status,
      ) {
    return _apiClient.patch(
      '/api/v1/seller/stores/'
          '$storeId/business-status',
      body: {
        'businessStatus': status,
      },
      decode: (Object? value) {
        return SellerStore.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<SellerStore> update(
      int storeId, {
        required String name,
        String? description,
        String? address,
        String? detailAddress,
        String? representativeCategory,
        String? imageUrl,
        String? phone,
        double? latitude,
        double? longitude,
        String? openTime,
        String? closeTime,
        List<String>? closedDays,
        bool? takeoutAvailable,
        bool? dineInAvailable,
        bool? orderAcceptingEnabled,
        List<String> tags = const [],
      }) {
    return _apiClient.patch(
      '/api/v1/seller/stores/$storeId',
      body: {
        'name': name,
        'description': description,
        'address': address,
        'detailAddress': detailAddress,
        'representativeCategory':
        representativeCategory,
        'imageUrl': imageUrl,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
        'openTime': openTime,
        'closeTime': closeTime,
        'closedDays': closedDays,
        'takeoutAvailable': takeoutAvailable,
        'dineInAvailable': dineInAvailable,
        'orderAcceptingEnabled':
        orderAcceptingEnabled,
        'tags': tags,
      },
      decode: (Object? value) {
        return SellerStore.fromJson(
          Map<String, Object?>.from(
            value as Map,
          ),
        );
      },
    );
  }

  @override
  Future<void> delete(
      int storeId,
      ) async {
    final bool deleted =
    await _apiClient.delete<bool>(
      '/api/v1/seller/stores/$storeId',
      decode: (Object? value) {
        return value as bool;
      },
    );

    if (!deleted) {
      throw StateError(
        'store deletion failed',
      );
    }
  }
}

class MemorySellerStoreRepository
    implements SellerStoreRepository {
  MemorySellerStoreRepository({
    List<SellerStore>? stores,
  }) : _stores =
      stores ??
          [
            const SellerStore(
              storeId: 1,
              storeType: 'LOCAL_STORE',
              name: '성수 커피 연구소',
              description: 'POPQ 메모리 스토어',
              representativeCategory: '카페',
              openTime: '09:00:00',
              closeTime: '21:00:00',
              status: 'ACTIVE',
              businessStatus: 'PRE_OPEN',
              myRole: 'OWNER',
            ),
          ];

  final List<SellerStore> _stores;

  @override
  Future<List<SellerStore>> findAll() async {
    return List<SellerStore>.unmodifiable(
      _stores,
    );
  }

  @override
  Future<List<SellerAddressSearchResult>>
  searchAddresses(
      String query,
      ) async {
    final String normalizedQuery =
    query.trim();

    if (normalizedQuery.isEmpty) {
      return const <
          SellerAddressSearchResult>[];
    }

    return <SellerAddressSearchResult>[
      SellerAddressSearchResult(
        addressName: normalizedQuery,
        roadAddressName: normalizedQuery,
        jibunAddressName:
        '부산 부산진구 부전동',
        zoneNo: '47291',
        latitude: 35.157746,
        longitude: 129.059319,
      ),
    ];
  }

  @override
  Future<SellerStore> findOne(
      int storeId,
      ) async {
    return _stores.firstWhere(
          (SellerStore store) {
        return store.storeId == storeId;
      },
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
  Future<String> uploadRepresentativeImage(
      String filePath,
      ) async {
    return filePath;
  }

  @override
  Future<SellerStore> create({
    required String storeType,
    required String name,
    String? description,
    String? address,
    String? detailAddress,
    String? representativeCategory,
    String? imageUrl,
    String? phone,
    double? latitude,
    double? longitude,
    String? openTime,
    String? closeTime,
    List<String> closedDays = const [],
    bool takeoutAvailable = true,
    bool dineInAvailable = true,
    bool orderAcceptingEnabled = true,
    List<String> tags = const [],
  }) async {
    final int nextStoreId = _stores.isEmpty
        ? 1
        : _stores
        .map(
          (SellerStore store) =>
      store.storeId,
    )
        .reduce(
          (int left, int right) =>
      left > right ? left : right,
    ) +
        1;

    final SellerStore store = SellerStore(
      storeId: nextStoreId,
      storeType: storeType,
      name: name,
      description: description,
      address: address,
      detailAddress: detailAddress,
      representativeCategory:
      representativeCategory,
      imageUrl: imageUrl,
      phone: phone,
      latitude: latitude,
      longitude: longitude,
      openTime: openTime,
      closeTime: closeTime,
      closedDays:
      List<String>.unmodifiable(
        closedDays,
      ),
      takeoutAvailable: takeoutAvailable,
      dineInAvailable: dineInAvailable,
      orderAcceptingEnabled:
      orderAcceptingEnabled,
      tags: List<String>.unmodifiable(
        tags,
      ),
      status: 'ACTIVE',
      businessStatus: 'PRE_OPEN',
      myRole: 'OWNER',
    );

    _stores.add(store);

    return store;
  }

  @override
  Future<SellerStore> changeBusinessStatus(
      int storeId,
      String status,
      ) async {
    final int index = _stores.indexWhere(
          (SellerStore store) {
        return store.storeId == storeId;
      },
    );

    if (index < 0) {
      throw StateError(
        'store not found',
      );
    }

    final SellerStore store = _stores[index];

    if (store.myRole != 'OWNER' &&
        store.myRole != 'MANAGER') {
      throw StateError(
        'store manager role is required',
      );
    }

    final SellerStore updated =
    store.copyWith(
      businessStatus: status,
    );

    _stores[index] = updated;

    return updated;
  }

  @override
  Future<SellerStore> update(
      int storeId, {
        required String name,
        String? description,
        String? address,
        String? detailAddress,
        String? representativeCategory,
        String? imageUrl,
        String? phone,
        double? latitude,
        double? longitude,
        String? openTime,
        String? closeTime,
        List<String>? closedDays,
        bool? takeoutAvailable,
        bool? dineInAvailable,
        bool? orderAcceptingEnabled,
        List<String> tags = const [],
      }) async {
    final int index = _stores.indexWhere(
          (SellerStore store) {
        return store.storeId == storeId;
      },
    );

    if (index < 0) {
      throw StateError(
        'store not found',
      );
    }

    final SellerStore store = _stores[index];

    if (store.myRole != 'OWNER' &&
        store.myRole != 'MANAGER') {
      throw StateError(
        'store manager role is required',
      );
    }

    final SellerStore updated = SellerStore(
      storeId: store.storeId,
      storeType: store.storeType,
      name: name,
      description: description,
      address: address,
      detailAddress:
      detailAddress ?? store.detailAddress,
      representativeCategory:
      representativeCategory ??
          store.representativeCategory,
      imageUrl:
      imageUrl ?? store.imageUrl,
      phone: phone ?? store.phone,
      latitude: latitude,
      longitude: longitude,
      openTime:
      openTime ?? store.openTime,
      closeTime:
      closeTime ?? store.closeTime,
      closedDays:
      List<String>.unmodifiable(
        closedDays ?? store.closedDays,
      ),
      takeoutAvailable:
      takeoutAvailable ??
          store.takeoutAvailable,
      dineInAvailable:
      dineInAvailable ??
          store.dineInAvailable,
      orderAcceptingEnabled:
      orderAcceptingEnabled ??
          store.orderAcceptingEnabled,
      tags: List<String>.unmodifiable(
        tags,
      ),
      status: store.status,
      businessStatus:
      store.businessStatus,
      myRole: store.myRole,
    );

    _stores[index] = updated;

    return updated;
  }

  @override
  Future<void> delete(
      int storeId,
      ) async {
    final int index = _stores.indexWhere(
          (SellerStore store) {
        return store.storeId == storeId;
      },
    );

    if (index < 0) {
      throw StateError(
        'store not found',
      );
    }

    final SellerStore store = _stores[index];

    if (store.myRole != 'OWNER') {
      throw StateError(
        'store owner role is required',
      );
    }

    _stores.removeAt(index);
  }
}

List<String> _readStringList(
    Object? value,
    ) {
  if (value is! List) {
    return const <String>[];
  }

  return value
      .whereType<String>()
      .toList(
    growable: false,
  );
}

String? _readNullableString(
    Object? value,
    ) {
  if (value == null) {
    return null;
  }

  final String text =
  value.toString().trim();

  return text.isEmpty
      ? null
      : text;
}