import 'package:popq_app_core/popq_app_core.dart';

import '../permissions/customer_permission_gateway.dart';

class CustomerLocationSearchResult {
  const CustomerLocationSearchResult({
    required this.addressName,
    required this.latitude,
    required this.longitude,
    this.roadAddressName,
    this.jibunAddressName,
    this.zoneNo,
  });

  factory CustomerLocationSearchResult.fromJson(
    Map<String, Object?> json,
  ) {
    final Object? latitudeValue = json['latitude'];
    final Object? longitudeValue = json['longitude'];

    if (latitudeValue is! num || longitudeValue is! num) {
      throw const InvalidResponseFailure(
        '탐색 위치 검색 결과의 좌표가 올바르지 않습니다.',
      );
    }

    final String addressName =
        json['addressName']?.toString().trim() ?? '';

    if (addressName.isEmpty) {
      throw const InvalidResponseFailure(
        '탐색 위치 검색 결과에 주소가 없습니다.',
      );
    }

    return CustomerLocationSearchResult(
      addressName: addressName,
      roadAddressName: _readNullableString(
        json['roadAddressName'],
      ),
      jibunAddressName: _readNullableString(
        json['jibunAddressName'],
      ),
      zoneNo: _readNullableString(
        json['zoneNo'],
      ),
      latitude: latitudeValue.toDouble(),
      longitude: longitudeValue.toDouble(),
    );
  }

  final String addressName;
  final String? roadAddressName;
  final String? jibunAddressName;
  final String? zoneNo;
  final double latitude;
  final double longitude;

  CustomerLocation get location => CustomerLocation(
        latitude: latitude,
        longitude: longitude,
      );

  String get displayLabel {
    final String? road = roadAddressName?.trim();
    if (road != null && road.isNotEmpty) {
      return road;
    }

    final String? jibun = jibunAddressName?.trim();
    if (jibun != null && jibun.isNotEmpty) {
      return jibun;
    }

    return addressName;
  }
}

abstract interface class CustomerLocationRepository {
  /// 좌표를 사람이 읽을 수 있는 위치 라벨로 변환합니다.
  ///
  /// 실패하면 null을 반환해 상위에서 지역 기본 라벨로 대체하도록 합니다.
  Future<String?> reverseGeocode(CustomerLocation location);

  /// 업체 탐색 기준으로 사용할 지역/주소 후보를 검색합니다.
  ///
  /// 소비자의 배송지나 거주지 주소를 저장하는 기능과는 별개입니다.
  Future<List<CustomerLocationSearchResult>> searchAddresses(
    String query,
  );
}

class ApiCustomerLocationRepository implements CustomerLocationRepository {
  ApiCustomerLocationRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<String?> reverseGeocode(
    CustomerLocation location,
  ) {
    return _apiClient.get(
      '/api/v1/public/location/reverse-geocode',
      query: {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      decode: (value) {
        final map = Map<String, Object?>.from(
          value as Map,
        );

        final label = map['label'] as String?;

        return (label == null || label.trim().isEmpty) ? null : label;
      },
    );
  }

  @override
  Future<List<CustomerLocationSearchResult>> searchAddresses(
    String query,
  ) {
    final String normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      return Future<List<CustomerLocationSearchResult>>.value(
        const <CustomerLocationSearchResult>[],
      );
    }

    return _apiClient.get<List<CustomerLocationSearchResult>>(
      '/api/v1/public/location/addresses',
      query: <String, Object?>{
        'query': normalizedQuery,
      },
      decode: (Object? value) {
        if (value is! List) {
          throw const InvalidResponseFailure(
            '탐색 위치 검색 응답 형식이 올바르지 않습니다.',
          );
        }

        return value.map(
          (Object? item) {
            if (item is! Map) {
              throw const InvalidResponseFailure(
                '탐색 위치 검색 결과 형식이 올바르지 않습니다.',
              );
            }

            return CustomerLocationSearchResult.fromJson(
              Map<String, Object?>.from(item),
            );
          },
        ).toList(growable: false);
      },
    );
  }
}

class MemoryCustomerLocationRepository implements CustomerLocationRepository {
  MemoryCustomerLocationRepository({
    this.label = '부산 해운대구',
    this.searchResults = const <CustomerLocationSearchResult>[],
  });

  final String? label;
  final List<CustomerLocationSearchResult> searchResults;

  @override
  Future<String?> reverseGeocode(
    CustomerLocation location,
  ) async {
    return label;
  }

  @override
  Future<List<CustomerLocationSearchResult>> searchAddresses(
    String query,
  ) async {
    final String normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return const <CustomerLocationSearchResult>[];
    }

    return searchResults.where(
      (CustomerLocationSearchResult result) {
        return result.addressName.toLowerCase().contains(normalizedQuery) ||
            (result.roadAddressName
                    ?.toLowerCase()
                    .contains(normalizedQuery) ??
                false) ||
            (result.jibunAddressName
                    ?.toLowerCase()
                    .contains(normalizedQuery) ??
                false);
      },
    ).toList(growable: false);
  }
}

String? _readNullableString(Object? value) {
  final String normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
