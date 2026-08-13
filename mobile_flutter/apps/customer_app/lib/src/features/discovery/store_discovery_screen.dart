//- 검색창
// - 로컬마켓/행사 필터
// - 선택한 업체
// - 하단 업체 카드

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'package:flutter/foundation.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../routing/customer_router.dart';
import '../favorites/customer_store_interest_controller.dart';
import '../permissions/customer_permission_gateway.dart';
import '../profile/customer_engagement_repository.dart';
import 'kakao_store_map.dart';
import 'kakao_store_map_web_stub.dart'
if (dart.library.js_interop) 'kakao_store_map_web.dart';
import 'store_discovery_controller.dart';
import 'store_discovery_repository.dart';

class StoreDiscoveryScreen extends StatefulWidget {
  const StoreDiscoveryScreen({
    required this.repository,
    required this.permissionGateway,
    this.engagementRepository,
    this.sessionController,
    super.key,
  });

  final StoreDiscoveryRepository repository;
  final CustomerPermissionGateway permissionGateway;

  /// 다음 단계에서 라우터가 전달합니다.
  ///
  /// 두 의존성이 모두 전달되면 탐색 화면의 하트가
  /// 실제 관심 매장 API와 연결됩니다.
  final CustomerEngagementRepository? engagementRepository;
  final SessionController? sessionController;

  @override
  State<StoreDiscoveryScreen> createState() => _StoreDiscoveryScreenState();
}

class _StoreDiscoveryScreenState extends State<StoreDiscoveryScreen> {
  static const _filters = [
    _StoreFilter(
      type: _StoreFilterType.all,
      label: '전체',
      icon: Icons.apps_rounded,
    ),
    _StoreFilter(
      type: _StoreFilterType.localStore,
      label: '로컬마켓',
      icon: Icons.storefront_rounded,
    ),
    _StoreFilter(
      type: _StoreFilterType.eventCommerce,
      label: '행사·이벤트',
      icon: Icons.celebration_rounded,
    ),
    _StoreFilter(
      type: _StoreFilterType.favorites,
      label: '마이픽',
      icon: Icons.favorite_rounded,
    ),
  ];

  late final StoreDiscoveryController _controller;

  late final KakaoStoreMapController _mapController;

  final TextEditingController _queryController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  final Set<int> _localFavoriteStoreIds = <int>{};

  CustomerStoreInterestController? _interestController;

  CustomerStore? _selectedStore;

  StoreWalkingRoute? _walkingRoute;

  bool _walkingRouteLoading = false;

  Object? _walkingRouteError;

  int _walkingRouteRequestSerial = 0;

  _StoreFilterType _selectedFilter = _StoreFilterType.all;

  bool _showSuggestions = false;

  bool _showInitialLocationChoice = false;

  bool _requestingInitialLocation = false;

  Timer? _mapSearchDebounce;

  Object? _lastShownRefreshError;

  bool _lastSearchWasMapMove = false;

  @override
  void initState() {
    super.initState();

    _mapController =
        KakaoStoreMapController();

    _controller = StoreDiscoveryController(
      repository: widget.repository,
      permissionGateway: widget.permissionGateway,
    )..addListener(_onControllerChanged);

    _createInterestController();
    _initializeDiscovery();
  }

  @override
  void didUpdateWidget(StoreDiscoveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final interestDependenciesChanged =
        !identical(
          oldWidget.engagementRepository,
          widget.engagementRepository,
        ) ||
        !identical(oldWidget.sessionController, widget.sessionController);

    if (!interestDependenciesChanged) {
      return;
    }

    _disposeInterestController();
    _createInterestController();
  }

  void _createInterestController() {
    final engagementRepository = widget.engagementRepository;
    final sessionController = widget.sessionController;

    if (engagementRepository == null || sessionController == null) {
      return;
    }

    final controller = CustomerStoreInterestController(
      repository: engagementRepository,
      sessionController: sessionController,
    )..addListener(_onInterestControllerChanged);

    _interestController = controller;
    unawaited(controller.load());
  }

  void _disposeInterestController() {
    _interestController
      ?..removeListener(_onInterestControllerChanged)
      ..dispose();

    _interestController = null;
  }

  void _onInterestControllerChanged() {
    if (!mounted) {
      return;
    }

    final interestController = _interestController;

    setState(() {
      /*
     * 로그아웃되면 마이픽 필터를 유지하지 않고
     * 전체 필터로 되돌립니다.
     */
      if (_selectedFilter == _StoreFilterType.favorites &&
          interestController != null &&
          !interestController.isSignedIn) {
        _selectedFilter = _StoreFilterType.all;

        _clearSelectedStoreState();
        return;
      }

      /*
     * 마이픽 화면에서 선택한 업체의 하트를 해제하면
     * 해당 업체는 필터 결과에서 빠지므로
     * 하단 선택 카드도 함께 닫습니다.
     */
      if (_selectedFilter != _StoreFilterType.favorites) {
        return;
      }

      final selectedStoreId = _selectedStore?.storeId;

      if (selectedStoreId != null &&
          !_favoriteStoreIds.contains(selectedStoreId)) {
        _clearSelectedStoreState();
      }
    });
  }

  @override
  void dispose() {
    _mapSearchDebounce?.cancel();

    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();

    _disposeInterestController();

    _queryController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  Future<void> _initializeDiscovery() async {
    _lastSearchWasMapMove = false;
    /*
   * 부산 기본 위치를 기준으로 업체 API를 호출합니다.
   *
   * 요청이 성공하면 인터넷과 백엔드 연결이 된 것으로 보고
   * 현재 위치 사용 여부를 묻는 안내를 표시합니다.
   */
    await _controller.initializeAtBusan(query: _queryController.text.trim());

    if (!mounted) {
      return;
    }

    /*
   * API 요청 자체가 실패한 경우에는
   * 위치 안내를 띄우지 않고 연결 오류 화면을 유지합니다.
   */
    if (_controller.status == DiscoveryStatus.failure) {
      return;
    }

    /*
   * 이미 위치 권한을 허용한 사용자에게는
   * 매번 선택 안내를 다시 묻지 않고 바로 현재 위치로 조회합니다.
   */
    final permissionStatus =
        await widget.permissionGateway.checkLocationPermission();

    if (!mounted) {
      return;
    }

    if (permissionStatus == PermissionDecision.granted) {
      await _useCurrentLocationFromInitialChoice();
      return;
    }

    setState(() {
      _showInitialLocationChoice = true;
    });
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    final refreshError = _controller.error;

    /*
   * 새 검색이 시작되면서 오류가 초기화되면
   * 다음 오류를 다시 표시할 수 있도록 상태를 정리합니다.
   */
    if (refreshError == null) {
      _lastShownRefreshError = null;
    } else if (_controller.hasCompletedInitialLoad &&
        !_controller.isRefreshing &&
        !identical(_lastShownRefreshError, refreshError)) {
      /*
     * 최초 연결 실패는 중앙 오류 화면에서 처리합니다.
     *
     * 이미 지도가 표시된 뒤의 재검색 실패만
     * SnackBar로 알려주고 기존 핀은 유지합니다.
     */
      _lastShownRefreshError = refreshError;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showTopSnackBar(
          const SnackBar(
            content: Text(
              '새 지역의 업체를 불러오지 못했습니다. '
              '기존 검색 결과를 유지합니다.',
            ),
          ),
        );
      });
    }

    setState(() {
      final selectedStoreId =
          _selectedStore?.storeId;

      if (selectedStoreId == null) {
        return;
      }

      /*
   * 새 검색 결과에도 선택 업체가 포함되어 있다면
   * 최신 업체 정보로 카드 객체만 갱신합니다.
   *
   * 검색 결과에서 벗어났더라도 기존 카드는 유지합니다.
   */
      for (final store in _controller.stores) {
        if (store.storeId == selectedStoreId) {
          _selectedStore = store;
          break;
        }
      }
    });
  }

  List<CustomerStore> get _filteredStores {
    final stores = _controller.stores;

    return switch (_selectedFilter) {
      _StoreFilterType.all => stores,

      _StoreFilterType.localStore =>
        stores.where((store) => store.storeType == 'LOCAL_STORE').toList(),

      _StoreFilterType.eventCommerce =>
        stores.where((store) => store.storeType == 'EVENT_COMMERCE').toList(),

      /*
     * 서버에서 받은 현재 지도 영역의 업체 중
     * 사용자가 찜한 업체만 표시합니다.
     */
      _StoreFilterType.favorites =>
        stores
            .where((store) => _favoriteStoreIds.contains(store.storeId))
            .toList(),
    };
  }

  /*
 * 카카오맵 마커에 표시할 현재 찜 업체 ID입니다.
 *
 * 실제 API Controller가 있으면 서버 상태를 사용하고,
 * 없으면 임시 로컬 즐겨찾기 상태를 사용합니다.
 */
  Set<int> get _favoriteStoreIds {
    final controller = _interestController;

    if (controller != null) {
      return controller.interestedStoreIds;
    }

    return Set<int>.unmodifiable(_localFavoriteStoreIds);
  }

  List<CustomerStore> get _searchSuggestions {
    final query = _queryController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return const [];
    }

    return _filteredStores
        .where((store) {
          final nameMatches = store.name.toLowerCase().contains(query);

          final addressMatches =
              store.address?.toLowerCase().contains(query) ?? false;

          final categoryMatches = store.representativeCategory
                  ?.toLowerCase()
                  .contains(query) ??
              false;

          final tagMatches = store.tags.any(
            (tag) => tag.toLowerCase().contains(query),
          );

          return nameMatches ||
              categoryMatches ||
              addressMatches ||
              tagMatches;
        })
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final stores = _filteredStores;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!kIsWeb)
          KakaoStoreMap(
            controller: _mapController,
            stores: stores,
            favoriteStoreIds: _favoriteStoreIds,
            currentLocation: _controller.location,
            searchCenter: _controller.searchCenter,
            selectedStoreId: _selectedStore?.storeId,
            onStoreSelected: _selectStore,
            onViewportIdle: _onMapViewportIdle,
          )
        else
          KakaoStoreMapWeb(
            controller: _mapController,
            stores: stores,
            favoriteStoreIds: _favoriteStoreIds,
            currentLocation: _controller.location,
            searchCenter: _controller.searchCenter,
            onStoreSelected: _selectStore,
            selectedStoreId: _selectedStore?.storeId,
            onViewportIdle: _onMapViewportIdle,
          ),

        _buildStatusOverlay(stores),

        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: PointerInterceptor(
            intercepting: kIsWeb,
            child: _buildTopControls(),
          ),
        ),

        Positioned(
          right: 16,
          bottom: _selectedStore == null ? 20 : 158,
          child: PointerInterceptor(
            intercepting: kIsWeb,
            child: _CurrentLocationButton(
              active: _controller.location != null,
              onPressed: _useCurrentLocation,
            ),
          ),
        ),

        if (_selectedStore != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
              child: PointerInterceptor(
                intercepting: kIsWeb,
                child: _SelectedStoreCard(
              store: _selectedStore!,
              favorite: _isFavorite(_selectedStore!.storeId),
              favoriteUpdating: _isFavoriteUpdating(_selectedStore!.storeId),
              walkingRoute: _walkingRoute,
              walkingRouteLoading: _walkingRouteLoading,
              walkingRouteError: _walkingRouteError,
              onWalkingRouteRetry: _reloadWalkingRouteForSelectedStore,
              onStoreLocationPressed:
              _focusSelectedStoreOnMap,
              onFavoritePressed: _toggleFavorite,
              onDetailsPressed: _openStoreDetail,
              onClose: () {
                setState(() {
                  _clearSelectedStoreState();
                });
              },
            ),
          ),
          ),
        if (_showInitialLocationChoice)
          Positioned.fill(
            child: PointerInterceptor(
              intercepting: kIsWeb,
              child: _InitialLocationChoice(
                requestingLocation: _requestingInitialLocation,
                onUseCurrentLocation:
                _useCurrentLocationFromInitialChoice,
                onContinueWithBusan: _continueWithBusan,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopControls() {
    return Column(
      children: [
        SearchBar(
          controller: _queryController,
          focusNode: _searchFocusNode,
          hintText: '업체명, 업종, 주소, 태그 검색',
          leading: const Icon(Icons.search_rounded),
          trailing: [
            if (_queryController.text.isNotEmpty)
              IconButton(
                tooltip: '검색어 지우기',
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
          onTap: () {
            if (_queryController.text.trim().isEmpty) {
              return;
            }

            setState(() {
              _showSuggestions = true;
            });
          },
          onChanged: (value) {
            setState(() {
              _showSuggestions = value.trim().isNotEmpty;
            });
          },
          onSubmitted: _submitSearch,
        ),

        const SizedBox(height: PopqSpacing.sm),

        if (_showSuggestions && _queryController.text.trim().isNotEmpty)
          _SearchSuggestionPanel(
            suggestions: _searchSuggestions,
            onSelected: _selectSearchSuggestion,
          )
        else
          _StoreFilterBar(
            filters: _filters,
            selectedFilter: _selectedFilter,
            onSelected: _selectFilter,
          ),

        if (_controller.location != null && !_showSuggestions) ...[
          const SizedBox(height: PopqSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.94),
              borderRadius: BorderRadius.circular(999),
              elevation: 1,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  '현재 위치 기준 10km 이내 · 가까운 순',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],

        if (_controller.isRefreshing && !_showSuggestions) ...[
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.center,
            child: _MapRefreshIndicator(),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusOverlay(List<CustomerStore> filteredStores) {
    /*
   * 최초 조회가 아닌 지도 이동 재검색에서는
   * 중앙의 큰 로딩·빈 결과 카드를 표시하지 않습니다.
   */
    if (_controller.isRefreshing) {
      return const SizedBox.shrink();
    }

    /*
   * 사용자가 지도를 이동해서 조회한 결과가 비어 있을 때는
   * 중앙의 결과 없음 카드를 표시하지 않습니다.
   */
    if (_lastSearchWasMapMove) {
      final viewportHasNoResult =
          _controller.status == DiscoveryStatus.empty ||
          (_controller.status == DiscoveryStatus.data &&
              filteredStores.isEmpty);

      if (viewportHasNoResult) {
        return const SizedBox.shrink();
      }
    }

    return switch (_controller.status) {
      DiscoveryStatus.loading => const Center(
        child: _MapStatusCard(
          icon: Icons.location_searching_rounded,
          message: '주변 업체를 찾고 있어요.',
          loading: true,
        ),
      ),

      DiscoveryStatus.failure => Center(
        child: _MapStatusCard(
          icon: Icons.cloud_off_rounded,
          message:
              '인터넷 또는 서버에 연결할 수 없습니다.\n'
              '연결 상태를 확인한 뒤 다시 시도해 주세요.',
          buttonLabel: '다시 시도',
          onPressed: () {
            _initializeDiscovery();
          },
        ),
      ),

      DiscoveryStatus.empty => const Center(
        child: _MapStatusCard(
          icon: Icons.storefront_outlined,
          message: '검색 조건에 맞는 업체가 없습니다.',
        ),
      ),

      DiscoveryStatus.data when filteredStores.isEmpty => Center(
        child: _MapStatusCard(
          icon: _selectedFilter == _StoreFilterType.favorites
              ? Icons.favorite_border_rounded
              : Icons.filter_alt_off_rounded,
          message: _selectedFilter == _StoreFilterType.favorites
              ? '이 지도 영역에 찜한 업체가 없습니다.'
              : '선택한 분류의 업체가 없습니다.',
        ),
      ),

      DiscoveryStatus.data => const SizedBox.shrink(),
    };
  }

  void _selectFilter(_StoreFilterType filter) {
    _searchFocusNode.unfocus();

    /*
   * 실제 즐겨찾기 Controller가 있는데 로그인하지 않은 경우,
   * 마이픽을 빈 화면으로 보여주지 않고 로그인 화면으로 이동합니다.
   *
   * Controller가 없는 메모리 테스트 환경에서는
   * 로컬 즐겨찾기 Set을 그대로 사용합니다.
   */
    final interestController = _interestController;

    if (filter == _StoreFilterType.favorites &&
        interestController != null &&
        !interestController.isSignedIn) {
      context.push(
        Uri(
          path: CustomerRoutes.signIn,
          queryParameters: const {'from': CustomerRoutes.discover},
        ).toString(),
      );

      return;
    }

    setState(() {
      _lastSearchWasMapMove = false;
      _selectedFilter = filter;
      _clearSelectedStoreState();
      _showSuggestions = false;
    });
  }

  Future<void> _submitSearch(String value) async {
    _searchFocusNode.unfocus();

    setState(() {
      _lastSearchWasMapMove = false;
      _showSuggestions = false;
      _clearSelectedStoreState();
    });

    await _controller.search(query: value);

    if (!mounted) {
      return;
    }

    if (value.trim().isNotEmpty &&
        _controller.status == DiscoveryStatus.empty &&
        _controller.error == null) {
      Timer? dismissTimer;
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          dismissTimer ??= Timer(const Duration(seconds: 3), () {
            if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          });
          return AlertDialog(
            title: const Text('검색 결과가 없습니다'),
            content: const Text('다른 검색어로 다시 찾아보세요.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
      dismissTimer?.cancel();
      if (!mounted) return;
      _queryController.clear();
      _controller.selectedTag = null;
      setState(() {
        _selectedFilter = _StoreFilterType.all;
        _showSuggestions = false;
        _clearSelectedStoreState();
      });
      await _controller.search();
      return;
    }

    final stores = _filteredStores;

    if (stores.length == 1) {
      _selectStore(stores.first);
    }
  }

  void _clearSearch() {
    _queryController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      _lastSearchWasMapMove = false;
      _showSuggestions = false;
      _clearSelectedStoreState();
    });

    _controller.search();
  }

  void _selectSearchSuggestion(CustomerStore store) {
    _queryController
      ..text = store.name
      ..selection = TextSelection.collapsed(offset: store.name.length);

    _selectStore(store);
  }

  void _onMapViewportIdle(KakaoMapViewport viewport) {
    /*
   * 이전에 예약해 둔 지도 검색이 있다면 취소합니다.
   *
   * 사용자가 연속해서 지도를 움직일 때
   * 중간 위치마다 API를 호출하지 않기 위한 처리입니다.
   */
    _mapSearchDebounce?.cancel();

    _lastSearchWasMapMove = true;

    /*
 * 지도를 이동해도 선택 업체 카드는 유지합니다.
 *
 * 검색 추천 목록만 닫고,
 * 사용자가 카드의 닫기 버튼을 누르거나
 * 다른 업체를 선택하기 전까지 현재 카드를 유지합니다.
 */
    if (_showSuggestions) {
      setState(() {
        _showSuggestions = false;
      });
    }

    _searchFocusNode.unfocus();

    /*
   * 지도가 멈춘 뒤 500ms 동안 추가 조작이 없을 때만
   * 현재 지도 영역의 업체를 다시 조회합니다.
   */
    _mapSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) {
        return;
      }

      await _controller.searchAround(
        center: viewport.center,
        radiusKm: viewport.radiusKm,
        query: _queryController.text.trim(),
      );
    });
  }

  void _selectStore(CustomerStore store) {
    _searchFocusNode.unfocus();

    setState(() {
      _showSuggestions = false;
      _selectedStore = store;

      /*
     * 이전에 선택한 업체의 도보 정보가
     * 새 업체 카드에 잠깐 보이지 않도록 초기화합니다.
     */
      _walkingRoute = null;
      _walkingRouteLoading = false;
      _walkingRouteError = null;
    });

    unawaited(_loadWalkingRoute(store));
  }

  Future<void> _focusSelectedStoreOnMap() async {
    final store = _selectedStore;

    final latitude = store?.latitude;
    final longitude = store?.longitude;

    if (store == null ||
        latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text(
              '업체 위치 정보가 없습니다.',
            ),
          ),
        );

      return;
    }

    /*
   * 이전에 예약된 지도 이동 검색이 있다면 취소합니다.
   *
   * 버튼으로 업체 위치에 이동한 뒤 발생하는
   * 새 viewport 이벤트만 처리하도록 합니다.
   */
    _mapSearchDebounce?.cancel();

    _searchFocusNode.unfocus();

    await _mapController.focusStoreLocation(
      CustomerLocation(
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  Future<void> _loadWalkingRoute(CustomerStore store) async {
    /*
   * 새 업체를 선택할 때마다 요청 번호를 증가시킵니다.
   *
   * A 업체를 조회하는 도중 B 업체를 선택했을 때
   * 늦게 도착한 A 업체 응답을 무시하기 위한 값입니다.
   */
    final requestSerial = ++_walkingRouteRequestSerial;

    /*
   * searchCenter가 아니라 실제 GPS 위치를 사용합니다.
   *
   * searchCenter는 사용자가 지도를 움직이면 바뀌지만,
   * location은 사용자의 실제 현재 위치입니다.
   */
    final startLocation = _controller.location;

    if (startLocation == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _walkingRoute = null;
        _walkingRouteLoading = false;
        _walkingRouteError = null;
      });

      return;
    }

    setState(() {
      _walkingRoute = null;
      _walkingRouteLoading = true;
      _walkingRouteError = null;
    });

    try {
      final route = await widget.repository.findWalkingRoute(
        storeId: store.storeId,
        startLocation: startLocation,
      );

      /*
     * 요청 중 화면이 닫혔거나,
     * 다른 업체가 선택되었거나,
     * 더 최신 요청이 시작된 경우에는
     * 현재 응답을 화면에 반영하지 않습니다.
     */
      if (!mounted ||
          requestSerial != _walkingRouteRequestSerial ||
          _selectedStore?.storeId != store.storeId) {
        return;
      }

      setState(() {
        _walkingRoute = route;
        _walkingRouteLoading = false;
        _walkingRouteError = null;
      });
    } catch (error) {
      if (!mounted ||
          requestSerial != _walkingRouteRequestSerial ||
          _selectedStore?.storeId != store.storeId) {
        return;
      }

      setState(() {
        _walkingRoute = null;
        _walkingRouteLoading = false;
        _walkingRouteError = error;
      });
    }
  }

  void _clearSelectedStoreState() {
    /*
   * 진행 중인 도보 경로 요청을 무효화합니다.
   *
   * 응답이 나중에 도착하더라도
   * 닫힌 카드에 결과가 다시 적용되지 않습니다.
   */
    _walkingRouteRequestSerial++;

    _selectedStore = null;
    _walkingRoute = null;
    _walkingRouteLoading = false;
    _walkingRouteError = null;
  }

  void _reloadWalkingRouteForSelectedStore() {
    final store = _selectedStore;

    if (store == null) {
      return;
    }

    unawaited(_loadWalkingRoute(store));
  }

  bool _isFavorite(int storeId) {
    final controller = _interestController;

    if (controller != null) {
      return controller.isInterested(storeId);
    }

    return _localFavoriteStoreIds.contains(storeId);
  }

  bool _isFavoriteUpdating(int storeId) {
    return _interestController?.isUpdating(storeId) ?? false;
  }

  Future<void> _toggleFavorite() async {
    final store = _selectedStore;

    if (store == null) {
      return;
    }

    final controller = _interestController;

    // 라우터가 새 의존성을 전달하기 전까지는
    // 기존 화면의 로컬 하트 동작을 유지합니다.
    if (controller == null) {
      setState(() {
        if (!_localFavoriteStoreIds.add(store.storeId)) {
          _localFavoriteStoreIds.remove(store.storeId);
        }
      });
      return;
    }

    final result = await controller.toggle(store.storeId);

    if (!mounted) {
      return;
    }

    if (result == CustomerStoreInterestToggleResult.added) {
      _showFavoriteMessage('${store.name}을(를) 찜에 추가했어요.');
      return;
    }

    if (result == CustomerStoreInterestToggleResult.removed) {
      _showFavoriteRemovedMessage(store);
      return;
    }

    if (result == CustomerStoreInterestToggleResult.signInRequired) {
      context.push(
        Uri(
          path: CustomerRoutes.signIn,
          queryParameters: const {'from': CustomerRoutes.discover},
        ).toString(),
      );
      return;
    }

    _showFavoriteMessage('찜 상태를 변경하지 못했어요. 잠시 후 다시 시도해 주세요.');
  }

  void _showFavoriteMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(SnackBar(content: Text(message)));
  }

  void _showFavoriteRemovedMessage(
      CustomerStore store,
      ) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentTopSnackBar()
      ..showTopSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${store.name}을(를) 찜에서 삭제했어요.',
          ),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () {
              unawaited(
                _restoreFavorite(store),
              );
            },
          ),
        ),
      );
  }

  Future<void> _restoreFavorite(
      CustomerStore store,
      ) async {
    final controller = _interestController;

    /*
   * 실제 관심 매장 컨트롤러가 아직 연결되지 않은
   * 로컬 테스트 상태도 같이 처리합니다.
   */
    if (controller == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _localFavoriteStoreIds.add(
          store.storeId,
        );
      });

      _showFavoriteMessage(
        '${store.name}을(를) 다시 찜했어요.',
      );

      return;
    }

    /*
   * SnackBar가 떠 있는 동안 다른 화면이나 동작에서
   * 이미 다시 찜했다면 toggle을 호출하지 않습니다.
   *
   * 여기서 무조건 toggle하면 이미 추가된 찜이
   * 다시 삭제될 수 있기 때문입니다.
   */
    if (controller.isInterested(store.storeId)) {
      return;
    }

    final result =
    await controller.toggle(store.storeId);

    if (!mounted) {
      return;
    }

    if (result ==
        CustomerStoreInterestToggleResult.added) {
      _showFavoriteMessage(
        '${store.name}을(를) 다시 찜했어요.',
      );
      return;
    }

    if (result ==
        CustomerStoreInterestToggleResult.signInRequired) {
      _showFavoriteMessage(
        '로그인이 만료되어 찜을 되돌리지 못했어요.',
      );
      return;
    }

    _showFavoriteMessage(
      '찜 삭제를 되돌리지 못했어요. 다시 시도해 주세요.',
    );
  }

  Future<void> _openStoreDetail() async {
    final storeId = _selectedStore?.storeId;

    if (storeId == null) {
      return;
    }

    await context.push('${CustomerRoutes.stores}/$storeId');

    if (!mounted) {
      return;
    }

    await _interestController?.load();
  }

  Future<void> _useCurrentLocationFromInitialChoice() async {
    if (_requestingInitialLocation) {
      return;
    }

    _mapSearchDebounce?.cancel();

    _lastSearchWasMapMove = false;

    setState(() {
      _requestingInitialLocation = true;
    });

    final decision = await _controller.useCurrentLocation(
      query: _queryController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    /*
   * 권한 허용 여부와 관계없이 최초 안내는 닫습니다.
   *
   * 허용하면 GPS 위치로 재조회되며,
   * 허용하지 않으면 이미 조회한 부산 위치를 그대로 사용합니다.
   */
    setState(() {
      _requestingInitialLocation = false;
      _showInitialLocationChoice = false;
    });

    if (decision == PermissionDecision.granted) {
      await _focusCurrentLocationOnMap();

      if (!mounted) {
        return;
      }

      _reloadWalkingRouteForSelectedStore();
      return;
    }

    _showLocationDecisionMessage(decision);
  }

  void _continueWithBusan() {
    setState(() {
      _showInitialLocationChoice = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    _mapSearchDebounce?.cancel();
    _lastSearchWasMapMove = false;

    final decision = await _controller.useCurrentLocation(
      query: _queryController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (decision == PermissionDecision.granted) {
      await _focusCurrentLocationOnMap();

      if (!mounted) {
        return;
      }

      _reloadWalkingRouteForSelectedStore();
      return;
    }

    _showLocationDecisionMessage(decision);
  }

  Future<void> _focusCurrentLocationOnMap() async {
    final location = _controller.location;

    if (location == null) {
      return;
    }

    await _mapController.focusStoreLocation(location);
  }

  void _showLocationDecisionMessage(PermissionDecision decision) {
    final message = switch (decision) {
      PermissionDecision.denied => '위치 권한을 허용하지 않아 부산 지역을 계속 보여드려요.',

      PermissionDecision.permanentlyDenied =>
        '현재 위치를 사용하려면 기기 설정에서 위치 권한을 허용해 주세요.',

      PermissionDecision.serviceDisabled => '기기의 위치 서비스가 꺼져 있어요.',

      PermissionDecision.timeout => '현재 위치를 확인하지 못해 부산 지역을 보여드려요.',

      PermissionDecision.granted => '',
    };

    if (message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showTopSnackBar(
      SnackBar(
        content: Text(message),
        action: decision == PermissionDecision.permanentlyDenied
            ? SnackBarAction(
                label: '설정',
                onPressed: widget.permissionGateway.openSettings,
              )
            : null,
      ),
    );
  }
}

enum _StoreFilterType { all, localStore, eventCommerce, favorites }

class _StoreFilter {
  const _StoreFilter({
    required this.type,
    required this.label,
    required this.icon,
  });

  final _StoreFilterType type;
  final String label;
  final IconData icon;
}

class _StoreFilterBar extends StatelessWidget {
  const _StoreFilterBar({
    required this.filters,
    required this.selectedFilter,
    required this.onSelected,
  });

  static const _accentColor = Color(0xFFB7FF00);

  static const _darkColor = Color(0xFF08110E);

  final List<_StoreFilter> filters;

  final _StoreFilterType selectedFilter;

  final ValueChanged<_StoreFilterType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.96),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: filters.map((filter) {
            final selected = filter.type == selectedFilter;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    onSelected(filter.type);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          filter.icon,
                          size: 15,
                          color: selected
                              ? _darkColor
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            filter.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? _darkColor : null,
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SearchSuggestionPanel extends StatelessWidget {
  const _SearchSuggestionPanel({
    required this.suggestions,
    required this.onSelected,
  });

  final List<CustomerStore> suggestions;
  final ValueChanged<CustomerStore> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: suggestions.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(PopqSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.search_off_rounded),
                    SizedBox(width: PopqSpacing.sm),
                    Expanded(child: Text('현재 목록에서 일치하는 업체가 없습니다.')),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: PopqSpacing.xs),
                shrinkWrap: true,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final store = suggestions[index];

                  return ListTile(
                    onTap: () => onSelected(store),
                    leading: _SelectedStoreThumbnail(
                      width: 40,
                      height: 40,
                      imageUrl: store.imageUrl,
                      fallbackIcon: _storeTypeIcon(store.storeType),
                    ),
                    title: Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        store.representativeCategory?.trim().isNotEmpty == true
                            ? store.representativeCategory!
                            : _storeTypeLabel(store.storeType),
                        if (store.fullAddress.isNotEmpty) store.fullAddress,
                        if (store.distanceMeters != null)
                          _formatDistance(store.distanceMeters!),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  );
                },
              ),
      ),
    );
  }
}

class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({required this.active, required this.onPressed});

  static const _accentColor = Color(0xFFB7FF00);
  static const _darkColor = Color(0xFF08110E);

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _accentColor : Theme.of(context).colorScheme.surface,
      elevation: 6,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: '현재 위치로 이동',
        onPressed: onPressed,
        icon: Icon(
          active ? Icons.my_location_rounded : Icons.location_searching_rounded,
          color: active ? _darkColor : null,
        ),
      ),
    );
  }
}

class _SelectedStoreThumbnail extends StatelessWidget {
  const _SelectedStoreThumbnail({
    required this.width,
    required this.height,
    required this.imageUrl,
    required this.fallbackIcon,
  });

  final double width;
  final double height;
  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: url.isEmpty
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: const Color(0xFFB7FF00),
      child: Icon(
        fallbackIcon,
        color: const Color(0xFF08110E),
        size: 24,
      ),
    );
  }
}

class _SelectedStoreCard extends StatelessWidget {
  const _SelectedStoreCard({
    required this.store,
    required this.favorite,
    required this.favoriteUpdating,
    required this.walkingRoute,
    required this.walkingRouteLoading,
    required this.walkingRouteError,
    required this.onWalkingRouteRetry,
    required this.onStoreLocationPressed,
    required this.onFavoritePressed,
    required this.onDetailsPressed,
    required this.onClose,
  });

  static const _greenColor = Color(0xFF17643E);

  final CustomerStore store;
  final bool favorite;
  final bool favoriteUpdating;
  final StoreWalkingRoute? walkingRoute;
  final bool walkingRouteLoading;
  final Object? walkingRouteError;
  final VoidCallback onWalkingRouteRetry;
  final VoidCallback onStoreLocationPressed;
  final VoidCallback onFavoritePressed;
  final VoidCallback onDetailsPressed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onDetailsPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _SelectedStoreThumbnail(
                width: 46,
                height: 46,
                imageUrl: store.imageUrl,
                fallbackIcon: _storeTypeIcon(store.storeType),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _storeTypeLabel(store.storeType),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: _greenColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _businessStatusLabel(store.businessStatus),
                          style: const TextStyle(
                            color: _greenColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (store.representativeCategory?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 2),
                      Text(
                        store.representativeCategory!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),

                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            store.fullAddress.isEmpty
                                ? '주소 정보 준비 중'
                                : store.fullAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _mapStoreHoursLabel(store),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    Row(
                      children: [
                        Icon(
                          Icons.directions_walk_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),

                        Expanded(
                          child: walkingRouteLoading
                              ? Row(
                            children: [
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '도보 경로 확인 중...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          )
                              : walkingRoute != null
                              ? Text(
                            '도보 '
                                '${_formatDistance(walkingRoute!.distanceMeters)}'
                                ' · 약 ${walkingRoute!.durationMinutes}분',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                              : walkingRouteError != null
                              ? Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: onWalkingRouteRetry,
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 14,
                              ),
                              label: const Text(
                                '도보 정보 다시 시도',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                              : Text(
                            '현재 위치를 켜면 도보 정보를 확인할 수 있어요.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: '선택 업체 위치로 이동',
                onPressed:
                store.latitude != null &&
                    store.longitude != null
                    ? onStoreLocationPressed
                    : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                icon: const Icon(
                  Icons.gps_fixed_rounded,
                  size: 19,
                  color: _greenColor,
                ),
              ),
              IconButton(
                tooltip: favorite ? '관심 업체 해제' : '관심 업체 추가',
                onPressed: favoriteUpdating ? null : onFavoritePressed,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                icon: favoriteUpdating
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: favorite ? Colors.redAccent : null,
                      ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 22),
              IconButton(
                tooltip: '선택 닫기',
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 34,
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialLocationChoice extends StatelessWidget {
  const _InitialLocationChoice({
    required this.requestingLocation,
    required this.onUseCurrentLocation,
    required this.onContinueWithBusan,
  });

  static const _accentColor = Color(0xFFB7FF00);
  static const _darkColor = Color(0xFF08110E);

  final bool requestingLocation;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onContinueWithBusan;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(0.42),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: _accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.near_me_rounded,
                          color: _darkColor,
                          size: 29,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        '내 주변 업체를 찾아볼까요?',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        '현재 위치를 사용하면 가까운 로컬마켓과 '
                        '행사·이벤트를 먼저 보여드려요.\n\n'
                        '위치를 사용하지 않아도 부산 지역을 '
                        '둘러볼 수 있습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: requestingLocation
                              ? null
                              : onUseCurrentLocation,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accentColor,
                            foregroundColor: _darkColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: requestingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _darkColor,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: Text(
                            requestingLocation ? '현재 위치 확인 중...' : '현재 위치로 보기',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: requestingLocation
                              ? null
                              : onContinueWithBusan,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            '부산에서 둘러보기',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '위치 설정은 지도 아래의 GPS 버튼에서 '
                        '언제든 다시 변경할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapRefreshIndicator extends StatelessWidget {
  const _MapRefreshIndicator();

  static const _darkColor = Color(0xFF08110E);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(999),
        elevation: 3,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _darkColor,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '이 지역의 업체를 찾고 있어요',
                style: TextStyle(
                  color: _darkColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapStatusCard extends StatelessWidget {
  const _MapStatusCard({
    required this.icon,
    required this.message,
    this.loading = false,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final bool loading;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              Icon(icon, size: 34),

            const SizedBox(height: PopqSpacing.sm),

            Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),

            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: PopqSpacing.sm),
              TextButton(onPressed: onPressed, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _storeTypeLabel(String storeType) {
  return switch (storeType) {
    'LOCAL_STORE' => '로컬마켓',
    'EVENT_COMMERCE' => '행사·이벤트',
    _ => '등록 업체',
  };
}

String _mapStoreHoursLabel(CustomerStore store) {
  final String hours = store.resolvedSchedule.todayLabel();
  final DateTime? start = store.operationStartDate;
  final DateTime? end = store.operationEndDate;
  if (start == null && end == null) return hours;
  final String startLabel = start == null
      ? ''
      : '${start.month}/${start.day}';
  final String endLabel = end == null ? '' : '${end.month}/${end.day}';
  final String period = start != null && end != null
      ? '$startLabel~$endLabel'
      : start != null
          ? '${store.storeType == 'EVENT_COMMERCE' ? '행사' : '영업'} $startLabel 시작'
          : '$endLabel까지';
  return '$hours · $period';
}

IconData _storeTypeIcon(String storeType) {
  return switch (storeType) {
    'EVENT_COMMERCE' => Icons.celebration_rounded,
    'LOCAL_STORE' => Icons.storefront_rounded,
    _ => Icons.place_rounded,
  };
}

String _businessStatusLabel(String businessStatus) {
  return switch (businessStatus) {
    'OPEN' => '영업 중',
    'PRE_OPEN' => '영업 준비',
    'CLOSED' => '영업 종료',
    'TEMPORARILY_CLOSED' => '임시 휴무',
    _ => businessStatus,
  };
}

String _formatDistance(int meters) {
  if (meters < 1000) {
    return '${meters}m';
  }

  return '${(meters / 1000).toStringAsFixed(1)}km';
}
