import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../discovery/store_discovery_repository.dart';
import '../orders/customer_order_repository.dart';

enum CustomerHomeStatus {
  initial,
  loading,
  data,
}

/// 홈의 임시 이미지 표현 종류입니다.
///
/// 아직 앱에 이미지 에셋과 매장 대표 이미지 API가 없기 때문에
/// 홈 화면에서 아이콘과 그라데이션을 선택하는 용도로 사용합니다.
/// 실제 이미지 API가 연결되면 삭제하거나 교체할 수 있습니다.
enum CustomerHomeVisualKind {
  taco,
  dessert,
  koreanFood,
  steak,
  membership,
}

/// 기간 한정 팝업·부스의 임시 표시 데이터입니다.
///
/// 백엔드 Store에 운영 기간 필드가 추가되거나
/// 홈 전용 API가 만들어지면 이 모델 대신 API 응답을 사용합니다.
class CustomerHomePopupItem {
  const CustomerHomePopupItem({
    required this.title,
    required this.locationLabel,
    required this.periodLabel,
    required this.badgeLabel,
    required this.visualKind,
    this.storeId,
  });

  final String title;
  final String locationLabel;
  final String periodLabel;
  final String badgeLabel;
  final CustomerHomeVisualKind visualKind;

  /// 실제 Store와 연결된 경우에만 사용합니다.
  ///
  /// 현재 임시 데이터에는 존재하지 않는 Store ID를 넣지 않기 위해
  /// null로 유지합니다.
  final int? storeId;
}

/// 추천 매장의 임시 표시 데이터입니다.
///
/// 실제 Store API 결과가 충분하지 않을 때만 사용하며,
/// 임의의 Store ID는 넣지 않습니다.
class CustomerHomeRecommendedItem {
  const CustomerHomeRecommendedItem({
    required this.name,
    required this.categoryLabel,
    required this.rating,
    required this.visualKind,
    this.storeId,
  });

  final String name;
  final String categoryLabel;
  final double rating;
  final CustomerHomeVisualKind visualKind;
  final int? storeId;
}

/// 회원 혜택 또는 서비스 안내 배너 데이터입니다.
class CustomerHomeBenefitBanner {
  const CustomerHomeBenefitBanner({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.visualKind,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final CustomerHomeVisualKind visualKind;
}

/// 홈 화면에서 사용하는 데이터 묶음입니다.
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

  /// 완료·취소되지 않은 최신 주문입니다.
  ///
  /// null이면 홈에서 진행 중 주문 영역 전체를 숨깁니다.
  final CustomerOrder? activeOrder;

  /// 실제 Store API에서 가져온 홈 홍보 매장입니다.
  final CustomerStore? featuredStore;

  /// API에서 조회된 EVENT_COMMERCE 매장입니다.
  ///
  /// 현재 API에는 운영 기간이 없으므로 실제 화면에서는
  /// 임시 팝업 데이터와 함께 사용할 수 있습니다.
  final List<CustomerStore> eventStores;

  /// featuredStore를 제외한 실제 LOCAL_STORE 추천 목록입니다.
  final List<CustomerStore> recommendedStores;

  final List<CustomerHomePopupItem> temporaryPopups;
  final List<CustomerHomeRecommendedItem> temporaryRecommendations;
  final List<CustomerHomeBenefitBanner> benefitBanners;

  /// Store API가 실패해 임시 콘텐츠만 표시 중인지 나타냅니다.
  final bool storeLoadFailed;

  /// 로그인 상태에서 주문 API 조회가 실패했는지 나타냅니다.
  final bool orderLoadFailed;
}

/// 홈 전용 임시 콘텐츠입니다.
///
/// 홈 UI 코드와 분리되어 있으므로 이후 API가 추가되면
/// 이 클래스만 삭제하고 Snapshot 생성 부분을 교체할 수 있습니다.
abstract final class CustomerHomeTemporaryContent {
  static const popupItems = <CustomerHomePopupItem>[
    CustomerHomePopupItem(
      title: '부산 야시장 타코 부스',
      locationLabel: '부산 야시장 A구역',
      periodLabel: '8월 10일까지',
      badgeLabel: '기간 한정',
      visualKind: CustomerHomeVisualKind.taco,
    ),
    CustomerHomePopupItem(
      title: '서면 푸드마켓 디저트 부스',
      locationLabel: '서면 푸드마켓',
      periodLabel: '8월 12일까지',
      badgeLabel: '이번 달',
      visualKind: CustomerHomeVisualKind.dessert,
    ),
  ];

  static const recommendedItems = <CustomerHomeRecommendedItem>[
    CustomerHomeRecommendedItem(
      name: '서면 분식당',
      categoryLabel: '분식 · 한식',
      rating: 4.6,
      visualKind: CustomerHomeVisualKind.koreanFood,
    ),
    CustomerHomeRecommendedItem(
      name: '그릴하우스',
      categoryLabel: '양식 · 스테이크',
      rating: 4.7,
      visualKind: CustomerHomeVisualKind.steak,
    ),
  ];

  static const benefitBanners = <CustomerHomeBenefitBanner>[
    CustomerHomeBenefitBanner(
      eyebrow: 'POPQ MEMBER',
      title: '주문과 관심 매장을\n한곳에서 관리하세요.',
      description: '주문 내역, 관심 스토어와 리뷰를 마이페이지에서 확인할 수 있어요.',
      actionLabel: '회원 혜택 보기',
      visualKind: CustomerHomeVisualKind.membership,
    ),
  ];
}

class CustomerHomeController extends ChangeNotifier {
  CustomerHomeController(
      this._storeDiscoveryRepository,
      this._orderRepository,
      this._sessionController,
      ) : _lastSignedIn = _sessionController.isSignedIn {
    _sessionController.addListener(_handleSessionChanged);
  }

  static const Set<String> _activeOrderStatuses = {
    'PLACED',
    'ACCEPTED',
    'PREPARING',
    'READY',
  };

  final StoreDiscoveryRepository _storeDiscoveryRepository;
  final CustomerOrderRepository _orderRepository;
  final SessionController _sessionController;

  CustomerHomeStatus status = CustomerHomeStatus.initial;
  CustomerHomeSnapshot? snapshot;

  bool _lastSignedIn;
  bool _disposed = false;
  int _requestVersion = 0;

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

    if (_disposed || requestVersion != _requestVersion) {
      return;
    }

    final stores = storeResult.value;
    final orders = orderResult.value;

    final activeOrder = _findActiveOrder(orders);
    final featuredStore = _findFeaturedStore(
      stores: stores,
      orders: orders,
      activeOrder: activeOrder,
    );

    final eventStores = stores
        .where(
          (store) => store.storeType == 'EVENT_COMMERCE',
    )
        .toList(
      growable: false,
    );

    final recommendedStores = stores
        .where(
          (store) =>
      store.storeType == 'LOCAL_STORE' &&
          store.storeId != featuredStore?.storeId,
    )
        .take(3)
        .toList(
      growable: false,
    );

    snapshot = CustomerHomeSnapshot(
      activeOrder: activeOrder,
      featuredStore: featuredStore,
      eventStores: List.unmodifiable(eventStores),
      recommendedStores: List.unmodifiable(
        recommendedStores,
      ),
      temporaryPopups:
      CustomerHomeTemporaryContent.popupItems,
      temporaryRecommendations:
      CustomerHomeTemporaryContent.recommendedItems,
      benefitBanners:
      CustomerHomeTemporaryContent.benefitBanners,
      storeLoadFailed: storeResult.error != null,
      orderLoadFailed: orderResult.error != null,
    );

    status = CustomerHomeStatus.data;
    _notifySafely();
  }

  Future<void> refresh() {
    return load();
  }

  Future<_HomeLoadResult<List<CustomerStore>>>
  _loadStores() async {
    try {
      final stores =
      await _storeDiscoveryRepository.search();

      return _HomeLoadResult<List<CustomerStore>>(
        value: List.unmodifiable(stores),
      );
    } catch (error) {
      return _HomeLoadResult<List<CustomerStore>>(
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
      return const _HomeLoadResult<List<CustomerOrder>>(
        value: [],
      );
    }

    try {
      final orders = await _orderRepository.findAll();

      return _HomeLoadResult<List<CustomerOrder>>(
        value: List.unmodifiable(orders),
      );
    } catch (error) {
      return _HomeLoadResult<List<CustomerOrder>>(
        value: const [],
        error: error,
      );
    }
  }

  CustomerOrder? _findActiveOrder(
      List<CustomerOrder> orders,
      ) {
    for (final order in orders) {
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

    // 진행 중 주문 매장을 가장 먼저 홍보 매장으로 사용합니다.
    if (activeOrder != null) {
      final activeOrderStore = _findStoreById(
        stores,
        activeOrder.storeId,
      );

      if (activeOrderStore != null) {
        return activeOrderStore;
      }
    }

    // 진행 중 주문이 없으면 최근 주문에 실제로 사용한 매장을 찾습니다.
    for (final order in orders) {
      final orderedStore = _findStoreById(
        stores,
        order.storeId,
      );

      if (orderedStore != null) {
        return orderedStore;
      }
    }

    // 주문 기록이 없거나 로그아웃 상태라면
    // 공개 Store API의 LOCAL_STORE를 사용합니다.
    for (final store in stores) {
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
    for (final store in stores) {
      if (store.storeId == storeId) {
        return store;
      }
    }

    return null;
  }

  void _handleSessionChanged() {
    final signedIn = _sessionController.isSignedIn;

    if (_lastSignedIn == signedIn) {
      return;
    }

    _lastSignedIn = signedIn;
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