import 'package:popq_app_core/popq_app_core.dart';

import '../permissions/customer_permission_gateway.dart';

/// 사용자가 선택한 시/도 + 구/군의 업체 탐색 기준 위치입니다.
///
/// 소비자 주소/배송지 정보가 아니라 홈과 탐색 화면에서
/// 주변 업체를 조회하기 위한 대표 좌표만 담습니다.
final class CustomerRegionCenter {
  const CustomerRegionCenter({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  factory CustomerRegionCenter.fromJson(
    Map<String, Object?> json,
  ) {
    final String label = json['label']?.toString().trim() ?? '';
    final double? latitude = _readDouble(json['latitude']);
    final double? longitude = _readDouble(json['longitude']);

    if (label.isEmpty || latitude == null || longitude == null) {
      throw const InvalidResponseFailure(
        '탐색 지역 중심 좌표 응답 형식이 올바르지 않습니다.',
      );
    }

    return CustomerRegionCenter(
      label: label,
      latitude: latitude,
      longitude: longitude,
    );
  }

  final String label;
  final double latitude;
  final double longitude;

  CustomerLocation get location => CustomerLocation(
        latitude: latitude,
        longitude: longitude,
      );
}

/// 이전 검색형 화면과 다음 단계 사이의 컴파일 호환을 위한 임시 모델입니다.
///
/// 드롭다운 UI 전환이 완료되면 제거할 예정입니다.
@Deprecated('드롭다운 지역 선택 방식으로 전환 중입니다.')
final class CustomerLocationSearchResult {
  const CustomerLocationSearchResult({
    required this.addressName,
    required this.latitude,
    required this.longitude,
    this.roadAddressName,
    this.jibunAddressName,
    this.zoneNo,
  });

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
  Future<String?> reverseGeocode(CustomerLocation location);

  /// 드롭다운에서 선택한 시/도 + 구/군의 대표 탐색 좌표를 조회합니다.
  ///
  /// [district]가 `전체`이면 해당 시/도의 대표 좌표를 반환합니다.
  Future<CustomerRegionCenter> getRegionCenter({
    required String province,
    required String district,
  });

  /// 이전 검색형 화면과 다음 단계 사이의 컴파일 호환용입니다.
  ///
  /// 백엔드의 `/addresses` API는 더 이상 사용하지 않으므로
  /// 항상 빈 목록을 반환합니다.
  @Deprecated('getRegionCenter()를 사용하세요.')
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
      query: <String, Object?>{
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      decode: (Object? value) {
        if (value is! Map) {
          throw const InvalidResponseFailure(
            '현재 위치 주소 응답 형식이 올바르지 않습니다.',
          );
        }

        final Map<String, Object?> map =
            Map<String, Object?>.from(value);
        final String label = map['label']?.toString().trim() ?? '';

        return label.isEmpty ? null : label;
      },
    );
  }

  @override
  Future<CustomerRegionCenter> getRegionCenter({
    required String province,
    required String district,
  }) {
    final String normalizedProvince = province.trim();
    final String normalizedDistrict = district.trim().isEmpty
        ? '전체'
        : district.trim();

    if (normalizedProvince.isEmpty) {
      return Future<CustomerRegionCenter>.error(
        ArgumentError.value(
          province,
          'province',
          '시/도를 선택해 주세요.',
        ),
      );
    }

    return _apiClient.get<CustomerRegionCenter>(
      '/api/v1/public/location/region-center',
      query: <String, Object?>{
        'province': normalizedProvince,
        'district': normalizedDistrict,
      },
      decode: (Object? value) {
        if (value is! Map) {
          throw const InvalidResponseFailure(
            '탐색 지역 중심 좌표 응답 형식이 올바르지 않습니다.',
          );
        }

        return CustomerRegionCenter.fromJson(
          Map<String, Object?>.from(value),
        );
      },
    );
  }

  @override
  Future<List<CustomerLocationSearchResult>> searchAddresses(
    String query,
  ) async {
    return const <CustomerLocationSearchResult>[];
  }
}

class MemoryCustomerLocationRepository
    implements CustomerLocationRepository {
  MemoryCustomerLocationRepository({
    this.label = '부산 해운대구',
    Map<String, CustomerRegionCenter>? regionCenters,
  }) : regionCenters = regionCenters ??
            const <String, CustomerRegionCenter>{
              '부산광역시|전체': CustomerRegionCenter(
                label: '부산',
                latitude: 35.1796,
                longitude: 129.0756,
              ),
              '부산광역시|해운대구': CustomerRegionCenter(
                label: '부산 해운대구',
                latitude: 35.1631,
                longitude: 129.1635,
              ),
              '서울특별시|전체': CustomerRegionCenter(
                label: '서울',
                latitude: 37.5665,
                longitude: 126.9780,
              ),
              '서울특별시|성동구': CustomerRegionCenter(
                label: '서울 성동구',
                latitude: 37.5633,
                longitude: 127.0371,
              ),
            };

  final String? label;
  final Map<String, CustomerRegionCenter> regionCenters;

  @override
  Future<String?> reverseGeocode(
    CustomerLocation location,
  ) async {
    return label;
  }

  @override
  Future<CustomerRegionCenter> getRegionCenter({
    required String province,
    required String district,
  }) async {
    final String normalizedProvince = province.trim();
    final String normalizedDistrict = district.trim().isEmpty
        ? '전체'
        : district.trim();
    final String key = '$normalizedProvince|$normalizedDistrict';

    final CustomerRegionCenter? result = regionCenters[key];
    if (result != null) {
      return result;
    }

    final CustomerRegionCenter? provinceCenter =
        regionCenters['$normalizedProvince|전체'];
    if (provinceCenter != null) {
      return CustomerRegionCenter(
        label: normalizedDistrict == '전체'
            ? provinceCenter.label
            : '$normalizedProvince $normalizedDistrict',
        latitude: provinceCenter.latitude,
        longitude: provinceCenter.longitude,
      );
    }

    throw StateError('등록되지 않은 테스트 탐색 지역입니다: $key');
  }

  @override
  Future<List<CustomerLocationSearchResult>> searchAddresses(
    String query,
  ) async {
    return const <CustomerLocationSearchResult>[];
  }
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}
