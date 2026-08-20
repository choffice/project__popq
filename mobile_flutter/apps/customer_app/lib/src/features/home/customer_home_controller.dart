import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../discovery/customer_search_location_controller.dart';
import '../discovery/store_discovery_repository.dart';
import '../orders/customer_order_repository.dart';
import '../permissions/customer_permission_gateway.dart';
import 'customer_home_content.dart';
import 'customer_location_repository.dart';

enum CustomerHomeStatus {
  initial,
  loading,
  data,
}

/// 홈 화면에서 사용하는 전체 데이터 묶음입니다.
class CustomerHomeSnapshot {
  const CustomerHomeSnapshot({
    required this.eventStores,
    required this.recommendedStores,
    required this.benefitBanners,
    required this.regionLabel,
    required this.currentLocationLabel,
    required this.storeLoadFailed,
    required this.orderLoadFailed,
    this.activeOrder,
    this.featuredStore,
  });

  /// 완료·취소되지 않은 가장 최근 주문입니다.
  ///
  /// null이면 홈의 진행 중 주문 카드 영역을 표시하지 않습니다.
  final CustomerOrder? activeOrder;

  /// 실제 Store API에서 가져온 홈 홍보 매장입니다.
  final CustomerStore? featuredStore;

  /// 현재 탐색 좌표 주변의 EVENT_COMMERCE 매장입니다.
  final List<CustomerStore> eventStores;

  /// 홈 홍보 매장을 제외한 현재 탐색 좌표 주변 LOCAL_STORE 목록입니다.
  final List<CustomerStore> recommendedStores;

  /// 회원 혜택 또는 서비스 안내 배너입니다.
  final List<CustomerHomeBenefitBanner> benefitBanners;

  /// 홈 섹션에 표시할 탐색 위치 라벨입니다.
  final String regionLabel;

  /// 홈 상단에 표시할 탐색 위치 라벨입니다.
  final String currentLocationLabel;

  /// Store API 조회 실패 여부입니다.
  final bool storeLoadFailed;

  /// 주문 API 조회 실패 여부입니다.
  final bool orderLoadFailed;
}

class CustomerHomeController extends ChangeNotifier {
  CustomerHomeController(
    this._storeDiscoveryRepository,
    this._orderRepository,
    this._sessionController,
    CustomerPermissionGateway permissionGateway,
    CustomerLocationRepository locationRepository, {
    CustomerSearchLocationController? searchLocationController,
  })  : _locationRepository = locationRepository,
        _searchLocationController = searchLocationController ??
            CustomerSearchLocationController(
              permissionGateway: permissionGateway,
              locationRepository: locationRepository,
            ),
        _ownsSearchLocationController = searchLocationController == null,
        _lastSignedIn = _sessionController.isSignedIn {
    _sessionController.addListener(_handleSessionChanged);
    _searchLocationController.addListener(_handleSearchLocationChanged);

    _lastSearchLatitude = _searchLocationController.searchCenter.latitude;
    _lastSearchLongitude = _searchLocationController.searchCenter.longitude;
    _lastSearchRadiusKm = _searchLocationController.searchRadiusKm;
    _lastLocationLabel = _searchLocationController.displayLabel;
  }

  /// 홈 화면이 열려 있는 동안 주문 상태를 다시 확인하는 주기입니다.
  static const Duration _orderRefreshInterval = Duration(seconds: 15);

  /// 홈에서 진행 중 주문으로 취급하는 상태입니다.
  static const Set<String> _activeOrderStatuses = {
    'PLACED',
    'ACCEPTED',
    'PREPARING',
    'READY',
  };

  /// 이전 부산 구·군 선택 UI와의 컴파일 호환용입니다.
  ///
  /// 새 UI에서는 직접 주소/지역 검색을 사용하므로 목록을 제공하지 않습니다.
  static const List<String> supportedLocationLabels = <String>[];

  final StoreDiscoveryRepository _storeDiscoveryRepository;
  final CustomerOrderRepository _orderRepository;
  final SessionController _sessionController;
  final CustomerLocationRepository _locationRepository;
  final CustomerSearchLocationController _searchLocationController;
  final bool _ownsSearchLocationController;

  CustomerHomeStatus status = CustomerHomeStatus.initial;
  CustomerHomeSnapshot? snapshot;

  bool _isApplyingRegionSelection = false;
  String? regionSelectionError;

  bool get isApplyingRegionSelection => _isApplyingRegionSelection;

  List<CustomerStore> _stores = const <CustomerStore>[];
  List<CustomerOrder> _orders = const <CustomerOrder>[];

  Timer? _orderRefreshTimer;

  bool _lastSignedIn;
  bool _isRefreshingOrders = false;
  bool _disposed = false;

  int _requestVersion = 0;
  int _storeLocationRequestVersion = 0;

  late double _lastSearchLatitude;
  late double _lastSearchLongitude;
  late double _lastSearchRadiusKm;
  late String _lastLocationLabel;

  /// 앱을 켠 뒤 첫 [load] 호출이 끝났는지 여부입니다.
  bool hasCompletedInitialLoad = false;

  CustomerSearchLocationController get searchLocationController =>
      _searchLocationController;

  /// 이전 최근 지역 UI와의 호환용입니다.
  /// 새 구조에서는 소비자 주소를 저장하지 않고 탐색 위치만 관리합니다.
  List<String> get recentLocationLabels => const <String>[];

  /// 홈의 매장 정보와 주문 정보를 함께 조회합니다.
  ///
  /// 업체는 공통 탐색 위치의 위도/경도와 검색 반경을 기준으로 조회합니다.
  Future<void> load() async {
    final int requestVersion = ++_requestVersion;
    final bool signedIn = _sessionController.isSignedIn;

    status = CustomerHomeStatus.loading;
    _notifySafely();

    final Future<_HomeLoadResult<List<CustomerStore>>> storeFuture =
        _loadStoresAtCurrentSearchLocation();
    final Future<_HomeLoadResult<List<CustomerOrder>>> orderFuture =
        _loadOrders(signedIn: signedIn);

    final _HomeLoadResult<List<CustomerStore>> storeResult = await storeFuture;
    final _HomeLoadResult<List<CustomerOrder>> orderResult = await orderFuture;

    if (_disposed || requestVersion != _requestVersion) {
      return;
    }

    _stores = List<CustomerStore>.unmodifiable(storeResult.value);
    _orders = List<CustomerOrder>.unmodifiable(orderResult.value);

    _rememberCurrentSearchState();

    snapshot = _createSnapshot(
      stores: _stores,
      orders: _orders,
      storeLoadFailed: storeResult.error != null,
      orderLoadFailed: orderResult.error != null,
    );

    status = CustomerHomeStatus.data;
    hasCompletedInitialLoad = true;

    _syncOrderRefreshTimer(signedIn: signedIn);
    _notifySafely();
  }

  /// 사용자가 홈 화면을 아래로 당겼을 때 전체 데이터를 다시 조회합니다.
  Future<void> refresh() => load();

  /// 홈에서 현재 GPS 위치를 업체 탐색 기준으로 사용합니다.
  ///
  /// GPS 좌표가 확보되면 역지오코딩 성공 여부와 무관하게 true를 반환합니다.
  Future<bool> useCurrentLocation() async {
    final LocationRequestResult result =
        await _searchLocationController.useCurrentLocation();

    return result.location != null;
  }

  /// 위치 권한을 사용하지 않는 기본 부산 탐색 위치로 돌아갑니다.
  void returnToBusan() {
    _searchLocationController.returnToBusan();
  }

  /// 드롭다운에서 고른 시/도 + 구/군을 업체 탐색 기준 위치로 적용합니다.
  ///
  /// 소비자 주소를 저장하는 기능이 아니라, 선택 지역의 대표 좌표를 받아
  /// 홈과 탐색 탭이 함께 사용할 공통 탐색 위치를 변경합니다.
  Future<bool> selectRegion({
    required String province,
    required String district,
  }) async {
    if (_isApplyingRegionSelection) {
      return false;
    }

    final String normalizedProvince = province.trim();
    final String normalizedDistrict =
        district.trim().isEmpty ? '전체' : district.trim();

    if (normalizedProvince.isEmpty) {
      regionSelectionError = '시/도를 선택해 주세요.';
      _notifySafely();
      return false;
    }

    _isApplyingRegionSelection = true;
    regionSelectionError = null;
    _notifySafely();

    try {
      final CustomerRegionCenter center =
          await _locationRepository.getRegionCenter(
        province: normalizedProvince,
        district: normalizedDistrict,
      );

      await _searchLocationController.setAddressSearchLocation(
        location: center.location,
        label: center.label,
      );

      return true;
    } catch (_) {
      regionSelectionError = '선택한 지역의 위치를 불러오지 못했어요.';
      return false;
    } finally {
      _isApplyingRegionSelection = false;
      _notifySafely();
    }
  }

  /// 이전 검색형 화면과 다음 화면 교체 사이의 컴파일 호환용입니다.
  /// 새 드롭다운 UI에서는 사용하지 않습니다.
  @Deprecated('selectRegion()을 사용하세요.')
  Future<List<CustomerLocationSearchResult>> searchLocations(
    String query,
  ) {
    return _locationRepository.searchAddresses(query);
  }

  /// 이전 검색형 화면과 다음 화면 교체 사이의 컴파일 호환용입니다.
  @Deprecated('selectRegion()을 사용하세요.')
  Future<void> selectSearchLocation(
    CustomerLocationSearchResult result,
  ) {
    return _searchLocationController.setAddressSearchLocation(
      location: result.location,
      label: result.displayLabel,
    );
  }

  /// 아주 오래된 부산 구·군 선택 UI와의 컴파일 호환용입니다.
  /// 새 화면에서는 사용하지 않습니다.
  @Deprecated('selectRegion()을 사용하세요.')
  Future<void> selectLocationLabel(String locationLabel) async {
    final String normalized = locationLabel.trim();
    if (normalized == '부산' || normalized == '부산광역시') {
      returnToBusan();
    }
  }

  CustomerHomeSnapshot _createSnapshot({
    required List<CustomerStore> stores,
    required List<CustomerOrder> orders,
    required bool storeLoadFailed,
    required bool orderLoadFailed,
  }) {
    final CustomerOrder? activeOrder = _findActiveOrder(orders);

    final CustomerStore? featuredStore = _findFeaturedStore(
      stores: stores,
      orders: orders,
      activeOrder: activeOrder,
    );

    final List<CustomerStore> eventStores = stores
        .where((CustomerStore store) => store.storeType == 'EVENT_COMMERCE')
        .toList(growable: false);

    final List<CustomerStore> recommendedStores = stores
        .where(
          (CustomerStore store) =>
              store.storeType == 'LOCAL_STORE' &&
              store.storeId != featuredStore?.storeId,
        )
        .take(5)
        .toList(growable: false);

    final String locationLabel = _searchLocationController.displayLabel.trim();
    final String effectiveLabel = locationLabel.isEmpty ? '부산' : locationLabel;

    return CustomerHomeSnapshot(
      activeOrder: activeOrder,
      featuredStore: featuredStore,
      eventStores: List<CustomerStore>.unmodifiable(eventStores),
      recommendedStores: List<CustomerStore>.unmodifiable(recommendedStores),
      benefitBanners: CustomerHomeContent.benefitBanners,
      regionLabel: effectiveLabel,
      currentLocationLabel: effectiveLabel,
      storeLoadFailed: storeLoadFailed,
      orderLoadFailed: orderLoadFailed,
    );
  }

  /// 공통 탐색 위치 변경을 홈에 반영합니다.
  ///
  /// - 위도/경도/반경 변경: 주변 업체를 다시 조회합니다.
  /// - 역지오코딩으로 라벨만 변경: 기존 업체를 유지하고 화면 라벨만 갱신합니다.
  void _handleSearchLocationChanged() {
    if (_disposed) {
      return;
    }

    final double latitude = _searchLocationController.searchCenter.latitude;
    final double longitude = _searchLocationController.searchCenter.longitude;
    final double radiusKm = _searchLocationController.searchRadiusKm;
    final String label = _searchLocationController.displayLabel;

    final bool searchAreaChanged =
        latitude != _lastSearchLatitude ||
            longitude != _lastSearchLongitude ||
            radiusKm != _lastSearchRadiusKm;
    final bool labelChanged = label != _lastLocationLabel;

    _lastSearchLatitude = latitude;
    _lastSearchLongitude = longitude;
    _lastSearchRadiusKm = radiusKm;
    _lastLocationLabel = label;

    if (searchAreaChanged) {
      unawaited(_refreshStoresForSearchLocation());
      return;
    }

    if (labelChanged) {
      _rebuildSnapshotFromCachedData();
    }
  }

  Future<void> _refreshStoresForSearchLocation() async {
    if (_disposed) {
      return;
    }

    final int requestVersion = ++_storeLocationRequestVersion;
    final _HomeLoadResult<List<CustomerStore>> result =
        await _loadStoresAtCurrentSearchLocation();

    if (_disposed || requestVersion != _storeLocationRequestVersion) {
      return;
    }

    _stores = List<CustomerStore>.unmodifiable(result.value);

    final CustomerHomeSnapshot? currentSnapshot = snapshot;
    if (currentSnapshot == null) {
      return;
    }

    snapshot = _createSnapshot(
      stores: _stores,
      orders: _orders,
      storeLoadFailed: result.error != null,
      orderLoadFailed: currentSnapshot.orderLoadFailed,
    );

    _notifySafely();
  }

  void _rebuildSnapshotFromCachedData() {
    final CustomerHomeSnapshot? currentSnapshot = snapshot;

    if (currentSnapshot == null) {
      return;
    }

    snapshot = _createSnapshot(
      stores: _stores,
      orders: _orders,
      storeLoadFailed: currentSnapshot.storeLoadFailed,
      orderLoadFailed: currentSnapshot.orderLoadFailed,
    );

    _notifySafely();
  }

  void _rememberCurrentSearchState() {
    _lastSearchLatitude = _searchLocationController.searchCenter.latitude;
    _lastSearchLongitude = _searchLocationController.searchCenter.longitude;
    _lastSearchRadiusKm = _searchLocationController.searchRadiusKm;
    _lastLocationLabel = _searchLocationController.displayLabel;
  }


  Future<_HomeLoadResult<List<CustomerStore>>>
      _loadStoresAtCurrentSearchLocation() async {
    try {
      final List<CustomerStore> stores = await _storeDiscoveryRepository.search(
        location: _searchLocationController.searchCenter,
        radiusKm: _searchLocationController.searchRadiusKm,
      );

      return _HomeLoadResult<List<CustomerStore>>(
        value: List<CustomerStore>.unmodifiable(stores),
      );
    } catch (error) {
      return _HomeLoadResult<List<CustomerStore>>(
        value: const <CustomerStore>[],
        error: error,
      );
    }
  }

  Future<_HomeLoadResult<List<CustomerOrder>>> _loadOrders({
    required bool signedIn,
  }) async {
    if (!signedIn) {
      return const _HomeLoadResult<List<CustomerOrder>>(
        value: <CustomerOrder>[],
      );
    }

    try {
      final List<CustomerOrder> orders = await _orderRepository.findAll();

      return _HomeLoadResult<List<CustomerOrder>>(
        value: List<CustomerOrder>.unmodifiable(orders),
      );
    } catch (error) {
      return _HomeLoadResult<List<CustomerOrder>>(
        value: const <CustomerOrder>[],
        error: error,
      );
    }
  }

  void _syncOrderRefreshTimer({
    required bool signedIn,
  }) {
    if (!signedIn) {
      _cancelOrderRefreshTimer();
      return;
    }

    if (_orderRefreshTimer != null) {
      return;
    }

    _orderRefreshTimer = Timer.periodic(
      _orderRefreshInterval,
      (_) {
        unawaited(_refreshOrdersSilently());
      },
    );
  }

  void _cancelOrderRefreshTimer() {
    _orderRefreshTimer?.cancel();
    _orderRefreshTimer = null;
  }

  /// 홈 전체 로딩 표시 없이 주문 상태만 다시 조회합니다.
  Future<void> _refreshOrdersSilently() async {
    if (_disposed ||
        !_sessionController.isSignedIn ||
        _isRefreshingOrders ||
        status == CustomerHomeStatus.loading) {
      return;
    }

    _isRefreshingOrders = true;

    try {
      final List<CustomerOrder> orders = await _orderRepository.findAll();

      if (_disposed) {
        return;
      }

      _orders = List<CustomerOrder>.unmodifiable(orders);

      final CustomerHomeSnapshot? currentSnapshot = snapshot;
      if (currentSnapshot == null) {
        return;
      }

      snapshot = _createSnapshot(
        stores: _stores,
        orders: _orders,
        storeLoadFailed: currentSnapshot.storeLoadFailed,
        orderLoadFailed: false,
      );

      _notifySafely();
    } catch (_) {
      if (_disposed) {
        return;
      }

      final CustomerHomeSnapshot? currentSnapshot = snapshot;
      if (currentSnapshot == null) {
        return;
      }

      snapshot = CustomerHomeSnapshot(
        activeOrder: currentSnapshot.activeOrder,
        featuredStore: currentSnapshot.featuredStore,
        eventStores: currentSnapshot.eventStores,
        recommendedStores: currentSnapshot.recommendedStores,
        benefitBanners: currentSnapshot.benefitBanners,
        regionLabel: currentSnapshot.regionLabel,
        currentLocationLabel: currentSnapshot.currentLocationLabel,
        storeLoadFailed: currentSnapshot.storeLoadFailed,
        orderLoadFailed: true,
      );

      _notifySafely();
    } finally {
      _isRefreshingOrders = false;
    }
  }

  CustomerOrder? _findActiveOrder(List<CustomerOrder> orders) {
    for (final CustomerOrder order in orders) {
      if (_activeOrderStatuses.contains(order.status)) {
        return order;
      }
    }

    return null;
  }

  CustomerStore? _findFeaturedStore({
    required List<CustomerStore> stores,
    required List<CustomerOrder> orders,
    required CustomerOrder? activeOrder,
  }) {
    if (stores.isEmpty) {
      return null;
    }

    // 진행 중 주문 매장이 현재 탐색 결과에도 있으면 우선 표시합니다.
    if (activeOrder != null) {
      final CustomerStore? activeOrderStore =
          _findStoreById(stores, activeOrder.storeId);

      if (activeOrderStore != null) {
        return activeOrderStore;
      }
    }

    // 최근 주문 매장이 현재 탐색 결과 안에 있으면 우선 표시합니다.
    for (final CustomerOrder order in orders) {
      final CustomerStore? orderedStore = _findStoreById(stores, order.storeId);

      if (orderedStore != null) {
        return orderedStore;
      }
    }

    // 주문 기록과 관계없이 현재 탐색 위치 주변 LOCAL_STORE를 우선 사용합니다.
    for (final CustomerStore store in stores) {
      if (store.storeType == 'LOCAL_STORE') {
        return store;
      }
    }

    return stores.first;
  }

  CustomerStore? _findStoreById(
    List<CustomerStore> stores,
    int storeId,
  ) {
    for (final CustomerStore store in stores) {
      if (store.storeId == storeId) {
        return store;
      }
    }

    return null;
  }

  void _handleSessionChanged() {
    final bool signedIn = _sessionController.isSignedIn;

    if (_lastSignedIn == signedIn) {
      return;
    }

    _lastSignedIn = signedIn;

    if (!signedIn) {
      _cancelOrderRefreshTimer();
    }

    unawaited(load());
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _storeLocationRequestVersion++;

    _cancelOrderRefreshTimer();

    _sessionController.removeListener(_handleSessionChanged);
    _searchLocationController.removeListener(_handleSearchLocationChanged);

    if (_ownsSearchLocationController) {
      _searchLocationController.dispose();
    }

    super.dispose();
  }
}

class _HomeLoadResult<T> {
  const _HomeLoadResult({
    required this.value,
    this.error,
  });

  final T value;
  final Object? error;
}
