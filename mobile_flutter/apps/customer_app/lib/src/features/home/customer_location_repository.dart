import 'package:popq_app_core/popq_app_core.dart';

import '../permissions/customer_permission_gateway.dart';

abstract interface class CustomerLocationRepository {
  /// 좌표를 사람이 읽을 수 있는 위치 라벨로 변환합니다.
  ///
  /// 실패하면 null을 반환해 상위에서 지역 기본 라벨로 대체하도록 합니다.
  Future<String?> reverseGeocode(CustomerLocation location);
}

class ApiCustomerLocationRepository
    implements CustomerLocationRepository {
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

        return (label == null || label.trim().isEmpty)
            ? null
            : label;
      },
    );
  }
}

class MemoryCustomerLocationRepository
    implements CustomerLocationRepository {
  MemoryCustomerLocationRepository({
    this.label = '부산 해운대구',
  });

  final String? label;

  @override
  Future<String?> reverseGeocode(
      CustomerLocation location,
      ) async {
    return label;
  }
}
