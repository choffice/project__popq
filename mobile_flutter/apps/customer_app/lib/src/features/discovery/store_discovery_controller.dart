import 'dart:async';

import 'package:flutter/foundation.dart';

import '../permissions/customer_permission_gateway.dart';
import 'customer_search_location_controller.dart';
import 'store_discovery_repository.dart';

enum DiscoveryStatus {
  loading,
  data,
  empty,
  failure,
}

class StoreDiscoveryController extends ChangeNotifier {
  StoreDiscoveryController({
    required StoreDiscoveryRepository repository,
    required CustomerPermissionGateway permissionGateway,
    CustomerSearchLocationController? searchLocationController,
  })  : _repository = repository,
        _permissionGateway = permissionGateway,
        _searchLocationController = searchLocationController {
    final sharedLocation = _searchLocationController;

    if (sharedLocation != null) {
      _syncFromSharedLocation();
      sharedLocation.addListener(_handleSharedLocationChanged);
    }
  }

  /// 위치 권한을 사용하지 않았을 때 보여줄 부산 기본 중심입니다.
  ///
  /// 공통 탐색 위치 컨트롤러와 같은 부산시청 인근 좌표를 사용합니다.
  static const CustomerLocation busanDefaultCenter =
      CustomerSearchLocationController.busanDefaultCenter;

  static const double defaultRadiusKm =
      CustomerSearchLocationController.defaultRadiusKm;

  static const double currentLocationRadiusKm =
      CustomerSearchLocationController.currentLocationRadiusKm;

  final StoreDiscoveryRepository _repository;
  final CustomerPermissionGateway _permissionGateway;

  /// 홈과 탐색이 같은 검색 기준 위치를 공유할 때 사용합니다.
  ///
  /// 아직 화면에서 전달하지 않는 동안에는 null일 수 있으며,
  /// 이 경우 기존 탐색 화면 동작을 그대로 유지합니다.
  final CustomerSearchLocationController? _searchLocationController;

  DiscoveryStatus status = DiscoveryStatus.loading;

  List<CustomerStore> stores = const [];

  String? selectedTag;

  /// 실제 사용자 GPS 위치입니다.
  ///
  /// null이면 사용자가 위치를 허용하지 않았거나
  /// 아직 현재 위치를 요청하지 않은 상태입니다.
  /// 지도 위 현재 위치 표시용으로 사용합니다.
  CustomerLocation? location;

  /// 업체를 검색할 때 사용하는 지도 중심입니다.
  ///
  /// 공통 탐색 위치 컨트롤러가 전달된 경우에는
  /// 홈과 탐색이 같은 searchCenter를 사용합니다.
  CustomerLocation searchCenter = busanDefaultCenter;

  double searchRadiusKm = defaultRadiusKm;

  Object? error;

  /// 최초 업체 조회가 한 번이라도 정상 완료됐는지 나타냅니다.
  ///
  /// 결과가 0개여도 API 요청이 정상 완료됐다면 true입니다.
  bool hasCompletedInitialLoad = false;

  /// 기존 지도와 핀을 유지한 상태로
  /// 새로운 지역을 조회하고 있는지 나타냅니다.
  bool isRefreshing = false;

  /// 연속된 검색 요청 중 가장 최신 요청을 구분합니다.
  int _requestSequence = 0;

  /// 공통 탐색 위치가 바뀌면 탐색 컨트롤러의 좌표도 맞춥니다.
  ///
  /// 주소 라벨만 갱신된 경우에도 listener가 호출될 수 있으므로
  /// 여기서는 자동 API 검색까지 실행하지 않습니다.
  void _handleSharedLocationChanged() {
    final changed = _syncFromSharedLocation();

    if (changed) {
      notifyListeners();
    }
  }

  bool _syncFromSharedLocation() {
    final sharedLocation = _searchLocationController;

    if (sharedLocation == null) {
      return false;
    }

    final nextSearchCenter = sharedLocation.searchCenter;
    final nextSearchRadiusKm = sharedLocation.searchRadiusKm;
    final nextDeviceLocation = sharedLocation.currentDeviceLocation;

    final changed =
        searchCenter.latitude != nextSearchCenter.latitude ||
            searchCenter.longitude != nextSearchCenter.longitude ||
            searchRadiusKm != nextSearchRadiusKm ||
            location?.latitude != nextDeviceLocation?.latitude ||
            location?.longitude != nextDeviceLocation?.longitude;

    searchCenter = nextSearchCenter;
    searchRadiusKm = nextSearchRadiusKm;
    location = nextDeviceLocation;

    return changed;
  }

  /// 탐색 탭 최초 진입 시 실행합니다.
  ///
  /// 공통 탐색 위치가 연결되어 있으면 부산으로 강제로 되돌리지 않고
  /// 홈 또는 이전 지도에서 마지막으로 선택한 탐색 위치를 그대로 사용합니다.
  ///
  /// 공통 탐색 위치가 아직 연결되지 않은 기존 구성에서는
  /// 이전과 동일하게 부산 기본 위치로 시작합니다.
  Future<void> initializeAtBusan({
    String? query,
  }) async {
    if (_searchLocationController != null) {
      _syncFromSharedLocation();
    } else {
      location = null;
      searchCenter = busanDefaultCenter;
      searchRadiusKm = defaultRadiusKm;
    }

    await search(query: query);
  }

  /// 현재 검색 중심과 검색 반경을 사용해 업체 목록을 조회합니다.
  ///
  /// 위치 없는 전체 업체 조회는 하지 않습니다.
  Future<void> search({
    String? query,
  }) async {
    final requestId = ++_requestSequence;
    final isInitialRequest = !hasCompletedInitialLoad;

    error = null;

    if (isInitialRequest) {
      status = DiscoveryStatus.loading;
      isRefreshing = false;
    } else {
      isRefreshing = true;
    }

    notifyListeners();

    try {
      final searchedStores = await _repository.search(
        query: query,
        tag: selectedTag,
        location: searchCenter,
        radiusKm: searchRadiusKm,
      );

      if (requestId != _requestSequence) {
        return;
      }

      stores = searchedStores;
      status = stores.isEmpty ? DiscoveryStatus.empty : DiscoveryStatus.data;
      hasCompletedInitialLoad = true;
    } catch (caught) {
      if (requestId != _requestSequence) {
        return;
      }

      error = caught;

      if (!hasCompletedInitialLoad) {
        status = DiscoveryStatus.failure;
      }
    } finally {
      if (requestId == _requestSequence) {
        isRefreshing = false;
        notifyListeners();
      }
    }
  }

  /// GPS 버튼 또는 최초 위치 안내에서 호출합니다.
  ///
  /// 공통 탐색 위치가 연결되어 있으면 그 컨트롤러가 GPS 좌표와
  /// 홈 상단 표시용 위치 라벨을 함께 관리합니다.
  ///
  /// 아직 공통 컨트롤러를 전달하지 않은 화면에서는
  /// 기존 탐색 탭의 현재 위치 동작을 그대로 사용합니다.
  Future<PermissionDecision> useCurrentLocation({
    String? query,
  }) async {
    final sharedLocation = _searchLocationController;

    if (sharedLocation != null) {
      final result = await sharedLocation.useCurrentLocation();

      if (result.location != null) {
        _syncFromSharedLocation();
        await search(query: query);
      }

      return result.decision;
    }

    final result = await _permissionGateway.requestLocation();

    if (result.location != null) {
      location = result.location;
      searchCenter = result.location!;
      searchRadiusKm = currentLocationRadiusKm;

      await search(query: query);
    }

    return result.decision;
  }

  /// 사용자가 지도를 이동했을 때 호출합니다.
  ///
  /// 실제 GPS 위치는 변경하지 않고 업체 검색 기준점만 바꿉니다.
  /// 공통 탐색 위치가 연결되어 있으면 홈도 같은 지도 중심을 공유합니다.
  Future<void> searchAround({
    required CustomerLocation center,
    required double radiusKm,
    String? query,
  }) async {
    final normalizedRadiusKm = radiusKm.clamp(0.5, 30.0).toDouble();
    final sharedLocation = _searchLocationController;

    if (sharedLocation != null) {
      // 공통 컨트롤러는 좌표를 즉시 반영한 뒤 주소 라벨을 비동기로
      // 조회합니다. 주소 라벨 때문에 업체 재검색이 늦어지지 않도록
      // 이 Future는 기다리지 않습니다.
      unawaited(
        sharedLocation.setMapSearchCenter(
          center: center,
          radiusKm: normalizedRadiusKm,
        ),
      );

      _syncFromSharedLocation();
    } else {
      searchCenter = center;
      searchRadiusKm = normalizedRadiusKm;
    }

    await search(query: query);
  }

  /// 위치 권한을 사용하지 않는 부산 기본 탐색 위치로 돌아갑니다.
  Future<void> returnToBusan({
    String? query,
  }) async {
    final sharedLocation = _searchLocationController;

    if (sharedLocation != null) {
      sharedLocation.returnToBusan();
      _syncFromSharedLocation();
    } else {
      location = null;
      searchCenter = busanDefaultCenter;
      searchRadiusKm = defaultRadiusKm;
    }

    await search(query: query);
  }

  Future<void> selectTag(
    String? value, {
    String? query,
  }) async {
    selectedTag = selectedTag == value ? null : value;

    await search(query: query);
  }

  @override
  void dispose() {
    _searchLocationController?.removeListener(_handleSharedLocationChanged);
    super.dispose();
  }
}
