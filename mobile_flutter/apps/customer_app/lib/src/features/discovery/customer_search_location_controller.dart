import 'package:flutter/foundation.dart';

import '../home/customer_location_repository.dart';
import '../permissions/customer_permission_gateway.dart';

/// 구매자 앱에서 "업체를 어디 기준으로 탐색할지"를 나타냅니다.
///
/// 이 값은 소비자의 배송지/거주지 주소와는 전혀 다른 개념입니다.
/// 홈과 탐색 탭이 같은 검색 기준 위치를 공유하기 위해 사용합니다.
enum CustomerSearchLocationSource {
  /// 위치 권한을 사용하지 않을 때 적용하는 기본 부산 중심입니다.
  busanDefault,

  /// 휴대폰 GPS로 얻은 실제 현재 위치입니다.
  currentLocation,

  /// 사용자가 탐색 지도를 직접 움직여 지정한 위치입니다.
  map,

  /// 사용자가 주소 검색으로 직접 지정한 위치입니다.
  addressSearch,
}

class CustomerSearchLocationController extends ChangeNotifier {
  CustomerSearchLocationController({
    required CustomerPermissionGateway permissionGateway,
    required CustomerLocationRepository locationRepository,
  })  : _permissionGateway = permissionGateway,
        _locationRepository = locationRepository;

  /// 위치 권한을 사용하지 않았을 때 업체 탐색에 사용하는 기본 중심입니다.
  ///
  /// 부산시청 인근 좌표입니다.
  static const CustomerLocation busanDefaultCenter = CustomerLocation(
    latitude: 35.157778,
    longitude: 129.059167,
  );

  static const double defaultRadiusKm = 10;
  static const double currentLocationRadiusKm = 10;

  final CustomerPermissionGateway _permissionGateway;
  final CustomerLocationRepository _locationRepository;

  /// 업체 검색의 실제 기준 좌표입니다.
  CustomerLocation searchCenter = busanDefaultCenter;

  /// 업체 검색 반경입니다.
  double searchRadiusKm = defaultRadiusKm;

  /// 휴대폰 GPS로 확인한 실제 현재 위치입니다.
  ///
  /// 지도를 움직여 [searchCenter]가 달라져도 이 값은 유지합니다.
  /// 탐색 지도에서 현재 위치 마커를 표시할 때 사용할 수 있습니다.
  CustomerLocation? currentDeviceLocation;

  /// 현재 탐색 기준 위치가 어떻게 정해졌는지 나타냅니다.
  CustomerSearchLocationSource source =
      CustomerSearchLocationSource.busanDefault;

  /// 홈 상단 등에 보여줄 탐색 위치 이름입니다.
  ///
  /// 역지오코딩이 실패해도 좌표 자체는 정상적으로 사용할 수 있으므로
  /// 위치 설정 성공 여부와 이 라벨의 성공 여부는 분리합니다.
  String displayLabel = '부산';

  bool isResolvingLabel = false;

  /// 비동기 역지오코딩 요청이 겹쳤을 때 오래된 결과를 버리기 위한 번호입니다.
  int _labelRequestSequence = 0;

  /// GPS 현재 위치를 탐색 기준으로 사용합니다.
  ///
  /// GPS 좌표를 얻는 순간 위치 설정은 성공한 것으로 처리합니다.
  /// 좌표 -> 주소 라벨 변환이 실패하더라도 GPS 성공을 취소하지 않습니다.
  Future<LocationRequestResult> useCurrentLocation() async {
    final result = await _permissionGateway.requestLocation();
    final location = result.location;

    if (location == null) {
      return result;
    }

    currentDeviceLocation = location;
    searchCenter = location;
    searchRadiusKm = currentLocationRadiusKm;
    source = CustomerSearchLocationSource.currentLocation;

    notifyListeners();

    await _resolveDisplayLabel(
      location,
      fallbackLabel: '현재 위치',
    );

    return result;
  }

  /// 사용자가 지도를 움직였을 때 새로운 탐색 기준을 적용합니다.
  ///
  /// 실제 GPS 위치인 [currentDeviceLocation]은 변경하지 않습니다.
  Future<void> setMapSearchCenter({
    required CustomerLocation center,
    required double radiusKm,
  }) async {
    searchCenter = center;
    searchRadiusKm = _normalizeRadius(radiusKm);
    source = CustomerSearchLocationSource.map;

    notifyListeners();

    await _resolveDisplayLabel(
      center,
      fallbackLabel: '지도에서 선택한 위치',
    );
  }

  /// 주소 검색 결과를 탐색 기준으로 적용합니다.
  ///
  /// 현재 백엔드에 구매자용 주소 검색 API를 붙이면 이 메서드를 그대로
  /// 연결할 수 있도록 미리 분리해 둡니다.
  Future<void> setAddressSearchLocation({
    required CustomerLocation location,
    required String label,
    double radiusKm = defaultRadiusKm,
  }) async {
    searchCenter = location;
    searchRadiusKm = _normalizeRadius(radiusKm);
    source = CustomerSearchLocationSource.addressSearch;

    final normalizedLabel = label.trim();
    displayLabel = normalizedLabel.isEmpty ? '선택한 위치' : normalizedLabel;

    _labelRequestSequence++;
    isResolvingLabel = false;
    notifyListeners();
  }

  /// 위치 권한을 쓰지 않는 기본 부산 탐색 위치로 되돌립니다.
  void returnToBusan() {
    searchCenter = busanDefaultCenter;
    searchRadiusKm = defaultRadiusKm;
    source = CustomerSearchLocationSource.busanDefault;
    displayLabel = '부산';

    _labelRequestSequence++;
    isResolvingLabel = false;
    notifyListeners();
  }

  double _normalizeRadius(double radiusKm) {
    return radiusKm.clamp(0.5, 30.0).toDouble();
  }

  Future<void> _resolveDisplayLabel(
    CustomerLocation location, {
    required String fallbackLabel,
  }) async {
    final requestId = ++_labelRequestSequence;

    isResolvingLabel = true;
    notifyListeners();

    String? resolvedLabel;

    try {
      resolvedLabel = await _locationRepository.reverseGeocode(location);
    } catch (_) {
      // 주소 라벨 조회 실패는 탐색 위치 좌표 자체의 실패가 아닙니다.
    }

    if (requestId != _labelRequestSequence) {
      return;
    }

    final normalizedLabel = resolvedLabel?.trim();

    displayLabel = normalizedLabel == null || normalizedLabel.isEmpty
        ? fallbackLabel
        : normalizedLabel;

    isResolvingLabel = false;
    notifyListeners();
  }
}
