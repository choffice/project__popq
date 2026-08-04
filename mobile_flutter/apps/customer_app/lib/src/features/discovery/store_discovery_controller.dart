import 'package:flutter/foundation.dart';

import '../permissions/customer_permission_gateway.dart';
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
  })  : _repository = repository,
        _permissionGateway = permissionGateway;

  /*
   * GPS 사용을 선택하지 않았을 때 보여줄 부산 기본 중심입니다.
   *
   * 부산시청 인근 좌표이며, 실제 매장 데이터가 아니라
   * 최초 지도 및 업체 검색의 기준점으로만 사용합니다.
   */
  static final CustomerLocation busanDefaultCenter =
  CustomerLocation(
    latitude: 35.157778,
    longitude: 129.059167,
  );

  static const double defaultRadiusKm = 10;
  static const double currentLocationRadiusKm = 10;

  final StoreDiscoveryRepository _repository;
  final CustomerPermissionGateway _permissionGateway;

  DiscoveryStatus status = DiscoveryStatus.loading;

  List<CustomerStore> stores = const [];

  String? selectedTag;

  /*
   * 실제 사용자 GPS 위치입니다.
   *
   * null이면 사용자가 위치를 허용하지 않았거나
   * 아직 현재 위치를 요청하지 않은 상태입니다.
   *
   * 지도 위 파란 현재 위치 표시용으로 사용합니다.
   */
  CustomerLocation? location;

  /*
   * 업체를 검색할 때 사용하는 지도 중심입니다.
   *
   * 초기에는 부산 기본 위치이며,
   * GPS 사용 시 실제 위치로 바뀌고,
   * 추후 지도를 움직이면 지도 중심으로 바뀝니다.
   */
  CustomerLocation searchCenter = busanDefaultCenter;

  double searchRadiusKm = defaultRadiusKm;

  Object? error;

  /*
 * 최초 업체 조회가 한 번이라도 정상 완료됐는지 나타냅니다.
 *
 * 결과가 0개여도 API 요청이 정상 완료됐다면 true입니다.
 */
  bool hasCompletedInitialLoad = false;

/*
 * 기존 지도와 핀을 유지한 상태로
 * 새로운 지역을 조회하고 있는지 나타냅니다.
 */
  bool isRefreshing = false;

/*
 * 연속된 검색 요청 중 가장 최신 요청을 구분합니다.
 */
  int _requestSequence = 0;

  /*
   * 탐색 탭 최초 진입 시 실행합니다.
   *
   * 부산 기본 위치 주변 업체를 조회하면서
   * 실제 백엔드 연결 여부도 함께 확인합니다.
   */
  Future<void> initializeAtBusan({
    String? query,
  }) async {
    location = null;
    searchCenter = busanDefaultCenter;
    searchRadiusKm = defaultRadiusKm;

    await search(query: query);
  }

  /*
   * 현재 검색 중심과 검색 반경을 사용해
   * 업체 목록을 조회합니다.
   *
   * 이제 위치 없는 전체 업체 조회는 하지 않습니다.
   */
  Future<void> search({
    String? query,
  }) async {
    /*
   * 검색이 실행될 때마다 번호를 증가시킵니다.
   *
   * 이 요청이 완료됐을 때 번호가 달라져 있다면
   * 그 사이에 더 최신 검색이 시작됐다는 뜻입니다.
   */
    final requestId = ++_requestSequence;

    final isInitialRequest =
    !hasCompletedInitialLoad;

    error = null;

    if (isInitialRequest) {
      /*
     * 첫 진입에서는 아직 보여줄 지도 데이터가 없으므로
     * 기존의 큰 로딩 안내를 표시합니다.
     */
      status = DiscoveryStatus.loading;
      isRefreshing = false;
    } else {
      /*
     * 지도 이동·검색어 변경·GPS 재검색에서는
     * 기존 업체와 핀을 지우지 않습니다.
     */
      isRefreshing = true;
    }

    notifyListeners();

    try {
      final searchedStores =
      await _repository.search(
        query: query,
        tag: selectedTag,
        location: searchCenter,
        radiusKm: searchRadiusKm,
      );

      /*
     * 이 요청보다 나중에 실행된 검색이 있다면
     * 현재 결과는 오래된 것이므로 적용하지 않습니다.
     */
      if (requestId != _requestSequence) {
        return;
      }

      stores = searchedStores;

      status = stores.isEmpty
          ? DiscoveryStatus.empty
          : DiscoveryStatus.data;

      /*
     * 검색 결과가 비어 있더라도 API가 정상 응답했다면
     * 최초 연결 확인은 완료된 것입니다.
     */
      hasCompletedInitialLoad = true;
    } catch (caught) {
      if (requestId != _requestSequence) {
        return;
      }

      error = caught;

      if (!hasCompletedInitialLoad) {
        /*
       * 최초 요청 실패 시에는 지도 대신
       * 연결 실패 안내를 표시합니다.
       */
        status = DiscoveryStatus.failure;
      }

      /*
     * 이미 지도 데이터가 있는 상태에서 재검색이 실패하면
     * status와 기존 stores는 유지합니다.
     *
     * 따라서 기존 핀은 사라지지 않습니다.
     */
    } finally {
      /*
     * 최신 요청이 완료된 경우에만
     * 재검색 상태를 종료합니다.
     */
      if (requestId == _requestSequence) {
        isRefreshing = false;
        notifyListeners();
      }
    }
  }

  /*
   * GPS 버튼 또는 최초 위치 안내에서 호출합니다.
   *
   * 위치를 얻으면:
   * 1. 실제 현재 위치를 저장하고
   * 2. 검색 중심도 현재 위치로 옮긴 뒤
   * 3. 주변 업체를 다시 조회합니다.
   */
  Future<PermissionDecision> useCurrentLocation({
    String? query,
  }) async {
    final result =
    await _permissionGateway.requestLocation();

    if (result.location != null) {
      location = result.location;
      searchCenter = result.location!;
      searchRadiusKm = currentLocationRadiusKm;

      await search(query: query);
    }

    return result.decision;
  }

  /*
   * 사용자가 지도를 이동했을 때 호출할 메서드입니다.
   *
   * 실제 GPS 위치인 location은 변경하지 않고,
   * 업체 검색 기준점만 새 지도 중심으로 바꿉니다.
   */
  Future<void> searchAround({
    required CustomerLocation center,
    required double radiusKm,
    String? query,
  }) async {
    searchCenter = center;

    searchRadiusKm = radiusKm
        .clamp(
      0.5,
      30.0,
    )
        .toDouble();

    await search(query: query);
  }

  /*
   * 사용자가 위치를 쓰지 않고
   * 부산 기본 위치로 돌아가고 싶을 때 사용합니다.
   */
  Future<void> returnToBusan({
    String? query,
  }) async {
    location = null;
    searchCenter = busanDefaultCenter;
    searchRadiusKm = defaultRadiusKm;

    await search(query: query);
  }

  Future<void> selectTag(
      String? value, {
        String? query,
      }) async {
    selectedTag =
    selectedTag == value ? null : value;

    await search(query: query);
  }
}
