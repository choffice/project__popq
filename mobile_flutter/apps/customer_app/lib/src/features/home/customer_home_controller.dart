import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../discovery/store_discovery_repository.dart';
import '../orders/customer_order_repository.dart';
import 'customer_home_content.dart';

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
    required this.temporaryPopups,
    required this.temporaryRecommendations,
    required this.benefitBanners,
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

  /// 실제 Store API에서 가져온 EVENT_COMMERCE 매장입니다.
  final List<CustomerStore> eventStores;

  /// 홈 홍보 매장을 제외한 실제 LOCAL_STORE 추천 목록입니다.
  final List<CustomerStore> recommendedStores;

  /// 아직 API가 없는 기간 한정 팝업·부스 임시 콘텐츠입니다.
  final List<CustomerHomePopupItem> temporaryPopups;

  /// 실제 추천 매장이 부족할 때 사용하는 임시 콘텐츠입니다.
  final List<CustomerHomeRecommendedItem>
  temporaryRecommendations;

  /// 회원 혜택 또는 서비스 안내 배너입니다.
  final List<CustomerHomeBenefitBanner> benefitBanners;

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
      ) : _lastSignedIn = _sessionController.isSignedIn {
    _sessionController.addListener(
      _handleSessionChanged,
    );
  }

  /// 홈 화면이 열려 있는 동안 주문 상태를 다시 확인하는 주기입니다.
  static const Duration _orderRefreshInterval =
  Duration(seconds: 15);

  /// 홈에서 진행 중 주문으로 취급하는 상태입니다.
  static const Set<String> _activeOrderStatuses = {
    'PLACED',
    'ACCEPTED',
    'PREPARING',
    'READY',
  };

  final StoreDiscoveryRepository
  _storeDiscoveryRepository;

  final CustomerOrderRepository _orderRepository;

  final SessionController _sessionController;

  CustomerHomeStatus status =
      CustomerHomeStatus.initial;

  CustomerHomeSnapshot? snapshot;

  List<CustomerStore> _stores = const [];

  Timer? _orderRefreshTimer;

  bool _lastSignedIn;
  bool _isRefreshingOrders = false;
  bool _disposed = false;

  int _requestVersion = 0;

  /// 홈의 매장 정보와 주문 정보를 함께 조회합니다.
  Future<void> load() async {
    final requestVersion = ++_requestVersion;
    final signedIn = _sessionController.isSignedIn;

    status = CustomerHomeStatus.loading;
    _notifySafely();

    final storeFuture = _loadStores();

    final orderFuture = _loadOrders(
      signedIn: signedIn,
    );

    final storeResult = await storeFuture;
    final orderResult = await orderFuture;

    if (_disposed ||
        requestVersion != _requestVersion) {
      return;
    }

    final stores = storeResult.value;
    final orders = orderResult.value;

    _stores = List.unmodifiable(stores);

    snapshot = _createSnapshot(
      stores: stores,
      orders: orders,
      storeLoadFailed:
      storeResult.error != null,
      orderLoadFailed:
      orderResult.error != null,
    );

    status = CustomerHomeStatus.data;

    _syncOrderRefreshTimer(
      signedIn: signedIn,
    );

    _notifySafely();
  }

  /// 사용자가 홈 화면을 아래로 당겼을 때 전체 데이터를 다시 조회합니다.
  Future<void> refresh() {
    return load();
  }

  CustomerHomeSnapshot _createSnapshot({
    required List<CustomerStore> stores,
    required List<CustomerOrder> orders,
    required bool storeLoadFailed,
    required bool orderLoadFailed,
  }) {
    final activeOrder =
    _findActiveOrder(orders);

    final featuredStore = _findFeaturedStore(
      stores: stores,
      orders: orders,
      activeOrder: activeOrder,
    );

    final eventStores = stores
        .where(
          (store) =>
      store.storeType ==
          'EVENT_COMMERCE',
    )
        .toList(
      growable: false,
    );

    final recommendedStores = stores
        .where(
          (store) =>
      store.storeType ==
          'LOCAL_STORE' &&
          store.storeId !=
              featuredStore?.storeId,
    )
        .take(3)
        .toList(
      growable: false,
    );

    return CustomerHomeSnapshot(
      activeOrder: activeOrder,
      featuredStore: featuredStore,
      eventStores: List.unmodifiable(
        eventStores,
      ),
      recommendedStores: List.unmodifiable(
        recommendedStores,
      ),

      // 임시 콘텐츠는 customer_home_content.dart에서 가져옵니다.
      temporaryPopups:
      CustomerHomeTemporaryContent
          .popupItems,
      temporaryRecommendations:
      CustomerHomeTemporaryContent
          .recommendedItems,
      benefitBanners:
      CustomerHomeTemporaryContent
          .benefitBanners,

      storeLoadFailed: storeLoadFailed,
      orderLoadFailed: orderLoadFailed,
    );
  }

  Future<_HomeLoadResult<List<CustomerStore>>>
  _loadStores() async {
    try {
      final stores =
      await _storeDiscoveryRepository
          .search();

      return _HomeLoadResult<
          List<CustomerStore>>(
        value: List.unmodifiable(stores),
      );
    } catch (error) {
      return _HomeLoadResult<
          List<CustomerStore>>(
        value: const [],
        error: error,
      );
    }
  }

  Future<_HomeLoadResult<List<CustomerOrder>>>
  _loadOrders({
    required bool signedIn,
  }) async {
    if (!signedIn) {
      return const _HomeLoadResult<
          List<CustomerOrder>>(
        value: [],
      );
    }

    try {
      final orders =
      await _orderRepository.findAll();

      return _HomeLoadResult<
          List<CustomerOrder>>(
        value: List.unmodifiable(orders),
      );
    } catch (error) {
      return _HomeLoadResult<
          List<CustomerOrder>>(
        value: const [],
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
        unawaited(
          _refreshOrdersSilently(),
        );
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
      final orders =
      await _orderRepository.findAll();

      if (_disposed) {
        return;
      }

      final currentSnapshot = snapshot;

      if (currentSnapshot == null) {
        return;
      }

      snapshot = _createSnapshot(
        stores: _stores,
        orders: orders,
        storeLoadFailed:
        currentSnapshot.storeLoadFailed,
        orderLoadFailed: false,
      );

      _notifySafely();
    } catch (_) {
      if (_disposed) {
        return;
      }

      final currentSnapshot = snapshot;

      if (currentSnapshot == null) {
        return;
      }

      // 주문 갱신이 실패해도 기존 홈 데이터는 유지합니다.
      snapshot = CustomerHomeSnapshot(
        activeOrder:
        currentSnapshot.activeOrder,
        featuredStore:
        currentSnapshot.featuredStore,
        eventStores:
        currentSnapshot.eventStores,
        recommendedStores:
        currentSnapshot.recommendedStores,
        temporaryPopups:
        currentSnapshot.temporaryPopups,
        temporaryRecommendations:
        currentSnapshot
            .temporaryRecommendations,
        benefitBanners:
        currentSnapshot.benefitBanners,
        storeLoadFailed:
        currentSnapshot.storeLoadFailed,
        orderLoadFailed: true,
      );

      _notifySafely();
    } finally {
      _isRefreshingOrders = false;
    }
  }

  CustomerOrder? _findActiveOrder(
      List<CustomerOrder> orders,
      ) {
    for (final order in orders) {
      if (_activeOrderStatuses.contains(
        order.status,
      )) {
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

    // 진행 중 주문이 있으면 해당 주문의 매장을 우선 표시합니다.
    if (activeOrder != null) {
      final activeOrderStore =
      _findStoreById(
        stores,
        activeOrder.storeId,
      );

      if (activeOrderStore != null) {
        return activeOrderStore;
      }
    }

    // 진행 중 주문이 없으면 최근 주문에 사용한 매장을 찾습니다.
    for (final order in orders) {
      final orderedStore =
      _findStoreById(
        stores,
        order.storeId,
      );

      if (orderedStore != null) {
        return orderedStore;
      }
    }

    // 주문 기록이 없으면 공개된 LOCAL_STORE를 우선 사용합니다.
    for (final store in stores) {
      if (store.storeType ==
          'LOCAL_STORE') {
        return store;
      }
    }

    // LOCAL_STORE도 없다면 공개 매장 중 첫 번째 매장을 사용합니다.
    return stores.first;
  }

  CustomerStore? _findStoreById(
      List<CustomerStore> stores,
      int storeId,
      ) {
    for (final store in stores) {
      if (store.storeId == storeId) {
        return store;
      }
    }

    return null;
  }

  void _handleSessionChanged() {
    final signedIn =
        _sessionController.isSignedIn;

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

    _cancelOrderRefreshTimer();

    _sessionController.removeListener(
      _handleSessionChanged,
    );

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