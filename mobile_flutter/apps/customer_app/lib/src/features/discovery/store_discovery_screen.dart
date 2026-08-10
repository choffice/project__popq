//- 寃?됱갹
// - 濡쒖뺄留덉폆/?됱궗 ?꾪꽣
// - ?좏깮???낆껜
// - ?섎떒 ?낆껜 移대뱶

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
import 'store_discovery_controller.dart';
import 'store_discovery_repository.dart';

import 'kakao_store_map_web_stub.dart'
if (dart.library.js_interop) 'kakao_store_map_web.dart';

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

  /// ?ㅼ쓬 ?④퀎?먯꽌 ?쇱슦?곌? ?꾨떖?⑸땲??
  ///
  /// ???섏〈?깆씠 紐⑤몢 ?꾨떖?섎㈃ ?먯깋 ?붾㈃???섑듃媛
  /// ?ㅼ젣 愿??留ㅼ옣 API? ?곌껐?⑸땲??
  final CustomerEngagementRepository? engagementRepository;
  final SessionController? sessionController;

  @override
  State<StoreDiscoveryScreen> createState() => _StoreDiscoveryScreenState();
}

class _StoreDiscoveryScreenState extends State<StoreDiscoveryScreen> {
  static const _filters = [
    _StoreFilter(
      type: _StoreFilterType.all,
      label: '?꾩껜',
      icon: Icons.apps_rounded,
    ),
    _StoreFilter(
      type: _StoreFilterType.localStore,
      label: '濡쒖뺄留덉폆',
      icon: Icons.storefront_rounded,
    ),
    _StoreFilter(
      type: _StoreFilterType.eventCommerce,
      label: '?됱궗쨌?대깽??,
      icon: Icons.celebration_rounded,
    ),
    _StoreFilter(
      type: _StoreFilterType.favorites,
      label: '留덉씠??,
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
     * 濡쒓렇?꾩썐?섎㈃ 留덉씠???꾪꽣瑜??좎??섏? ?딄퀬
     * ?꾩껜 ?꾪꽣濡??섎룎由쎈땲??
     */
      if (_selectedFilter == _StoreFilterType.favorites &&
          interestController != null &&
          !interestController.isSignedIn) {
        _selectedFilter = _StoreFilterType.all;

        _clearSelectedStoreState();
        return;
      }

      /*
     * 留덉씠???붾㈃?먯꽌 ?좏깮???낆껜???섑듃瑜??댁젣?섎㈃
     * ?대떦 ?낆껜???꾪꽣 寃곌낵?먯꽌 鍮좎?誘濡?
     * ?섎떒 ?좏깮 移대뱶???④퍡 ?レ뒿?덈떎.
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
   * 遺??湲곕낯 ?꾩튂瑜?湲곗??쇰줈 ?낆껜 API瑜??몄텧?⑸땲??
   *
   * ?붿껌???깃났?섎㈃ ?명꽣?룰낵 諛깆뿏???곌껐????寃껋쑝濡?蹂닿퀬
   * ?꾩옱 ?꾩튂 ?ъ슜 ?щ?瑜?臾삳뒗 ?덈궡瑜??쒖떆?⑸땲??
   */
    await _controller.initializeAtBusan(query: _queryController.text.trim());

    if (!mounted) {
      return;
    }

    /*
   * API ?붿껌 ?먯껜媛 ?ㅽ뙣??寃쎌슦?먮뒗
   * ?꾩튂 ?덈궡瑜??꾩슦吏 ?딄퀬 ?곌껐 ?ㅻ쪟 ?붾㈃???좎??⑸땲??
   */
    if (_controller.status == DiscoveryStatus.failure) {
      return;
    }

    /*
   * ?대? ?꾩튂 沅뚰븳???덉슜???ъ슜?먯뿉寃뚮뒗
   * 留ㅻ쾲 ?좏깮 ?덈궡瑜??ㅼ떆 臾살? ?딄퀬 諛붾줈 ?꾩옱 ?꾩튂濡?議고쉶?⑸땲??
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
   * ??寃?됱씠 ?쒖옉?섎㈃???ㅻ쪟媛 珥덇린?붾릺硫?
   * ?ㅼ쓬 ?ㅻ쪟瑜??ㅼ떆 ?쒖떆?????덈룄濡??곹깭瑜??뺣━?⑸땲??
   */
    if (refreshError == null) {
      _lastShownRefreshError = null;
    } else if (_controller.hasCompletedInitialLoad &&
        !_controller.isRefreshing &&
        !identical(_lastShownRefreshError, refreshError)) {
      /*
     * 理쒖큹 ?곌껐 ?ㅽ뙣??以묒븰 ?ㅻ쪟 ?붾㈃?먯꽌 泥섎━?⑸땲??
     *
     * ?대? 吏?꾧? ?쒖떆???ㅼ쓽 ?ш????ㅽ뙣留?
     * SnackBar濡??뚮젮二쇨퀬 湲곗〈 ?? ?좎??⑸땲??
     */
      _lastShownRefreshError = refreshError;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showTopSnackBar(
          const SnackBar(
            content: Text(
              '??吏??쓽 ?낆껜瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲?? '
              '湲곗〈 寃??寃곌낵瑜??좎??⑸땲??',
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
   * ??寃??寃곌낵?먮룄 ?좏깮 ?낆껜媛 ?ы븿?섏뼱 ?덈떎硫?
   * 理쒖떊 ?낆껜 ?뺣낫濡?移대뱶 媛앹껜留?媛깆떊?⑸땲??
   *
   * 寃??寃곌낵?먯꽌 踰쀬뼱?щ뜑?쇰룄 湲곗〈 移대뱶???좎??⑸땲??
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
     * ?쒕쾭?먯꽌 諛쏆? ?꾩옱 吏???곸뿭???낆껜 以?
     * ?ъ슜?먭? 李쒗븳 ?낆껜留??쒖떆?⑸땲??
     */
      _StoreFilterType.favorites =>
        stores
            .where((store) => _favoriteStoreIds.contains(store.storeId))
            .toList(),
    };
  }

  /*
 * 移댁뭅?ㅻ㏊ 留덉빱???쒖떆???꾩옱 李??낆껜 ID?낅땲??
 *
 * ?ㅼ젣 API Controller媛 ?덉쑝硫??쒕쾭 ?곹깭瑜??ъ슜?섍퀬,
 * ?놁쑝硫??꾩떆 濡쒖뺄 利먭꺼李얘린 ?곹깭瑜??ъ슜?⑸땲??
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

          final tagMatches = store.tags.any(
            (tag) => tag.toLowerCase().contains(query),
          );

          return nameMatches ||
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
                onStoreLocationPressed: _focusSelectedStoreOnMap,
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
                onUseCurrentLocation: _useCurrentLocationFromInitialChoice,
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
          hintText: '?낆껜紐? 硫붾돱, 二쇱냼 寃??,
          leading: const Icon(Icons.search_rounded),
          trailing: [
            if (_queryController.text.isNotEmpty)
              IconButton(
                tooltip: '寃?됱뼱 吏?곌린',
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
                  '?꾩옱 ?꾩튂 湲곗? 10km ?대궡 쨌 媛源뚯슫 ??,
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
   * 理쒖큹 議고쉶媛 ?꾨땶 吏???대룞 ?ш??됱뿉?쒕뒗
   * 以묒븰????濡쒕뵫쨌鍮?寃곌낵 移대뱶瑜??쒖떆?섏? ?딆뒿?덈떎.
   */
    if (_controller.isRefreshing) {
      return const SizedBox.shrink();
    }

    /*
   * ?ъ슜?먭? 吏?꾨? ?대룞?댁꽌 議고쉶??寃곌낵媛 鍮꾩뼱 ?덉쓣 ?뚮뒗
   * 以묒븰??寃곌낵 ?놁쓬 移대뱶瑜??쒖떆?섏? ?딆뒿?덈떎.
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
          message: '二쇰? ?낆껜瑜?李얘퀬 ?덉뼱??',
          loading: true,
        ),
      ),

      DiscoveryStatus.failure => Center(
        child: _MapStatusCard(
          icon: Icons.cloud_off_rounded,
          message:
              '?명꽣???먮뒗 ?쒕쾭???곌껐?????놁뒿?덈떎.\n'
              '?곌껐 ?곹깭瑜??뺤씤?????ㅼ떆 ?쒕룄??二쇱꽭??',
          buttonLabel: '?ㅼ떆 ?쒕룄',
          onPressed: () {
            _initializeDiscovery();
          },
        ),
      ),

      DiscoveryStatus.empty => const Center(
        child: _MapStatusCard(
          icon: Icons.storefront_outlined,
          message: '寃??議곌굔??留욌뒗 ?낆껜媛 ?놁뒿?덈떎.',
        ),
      ),

      DiscoveryStatus.data when filteredStores.isEmpty => Center(
        child: _MapStatusCard(
          icon: _selectedFilter == _StoreFilterType.favorites
              ? Icons.favorite_border_rounded
              : Icons.filter_alt_off_rounded,
          message: _selectedFilter == _StoreFilterType.favorites
              ? '??吏???곸뿭??李쒗븳 ?낆껜媛 ?놁뒿?덈떎.'
              : '?좏깮??遺꾨쪟???낆껜媛 ?놁뒿?덈떎.',
        ),
      ),

      DiscoveryStatus.data => const SizedBox.shrink(),
    };
  }

  void _selectFilter(_StoreFilterType filter) {
    _searchFocusNode.unfocus();

    /*
   * ?ㅼ젣 利먭꺼李얘린 Controller媛 ?덈뒗??濡쒓렇?명븯吏 ?딆? 寃쎌슦,
   * 留덉씠?쎌쓣 鍮??붾㈃?쇰줈 蹂댁뿬二쇱? ?딄퀬 濡쒓렇???붾㈃?쇰줈 ?대룞?⑸땲??
   *
   * Controller媛 ?녿뒗 硫붾え由??뚯뒪???섍꼍?먯꽌??
   * 濡쒖뺄 利먭꺼李얘린 Set??洹몃?濡??ъ슜?⑸땲??
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

    final stores = _filteredStores;

    if (stores.length == 1) {
      _selectStore(stores.first);
      await _focusSelectedStoreOnMap();
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
      ..selection = TextSelection.collapsed(
        offset: store.name.length,
      );

    _selectStore(store);

    final latitude = store.latitude;
    final longitude = store.longitude;

    if (latitude == null || longitude == null) {
      return;
    }

    _mapSearchDebounce?.cancel();

    unawaited(
      _mapController.focusStoreLocation(
        CustomerLocation(
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );
  }

  void _onMapViewportIdle(KakaoMapViewport viewport) {
    /*
   * ?댁쟾???덉빟????吏??寃?됱씠 ?덈떎硫?痍⑥냼?⑸땲??
   *
   * ?ъ슜?먭? ?곗냽?댁꽌 吏?꾨? ?吏곸씪 ??
   * 以묎컙 ?꾩튂留덈떎 API瑜??몄텧?섏? ?딄린 ?꾪븳 泥섎━?낅땲??
   */
    _mapSearchDebounce?.cancel();

    _lastSearchWasMapMove = true;

    /*
 * 吏?꾨? ?대룞?대룄 ?좏깮 ?낆껜 移대뱶???좎??⑸땲??
 *
 * 寃??異붿쿇 紐⑸줉留??リ퀬,
 * ?ъ슜?먭? 移대뱶???リ린 踰꾪듉???꾨Ⅴ嫄곕굹
 * ?ㅻⅨ ?낆껜瑜??좏깮?섍린 ?꾧퉴吏 ?꾩옱 移대뱶瑜??좎??⑸땲??
 */
    if (_showSuggestions) {
      setState(() {
        _showSuggestions = false;
      });
    }

    _searchFocusNode.unfocus();

    /*
   * 吏?꾧? 硫덉텣 ??500ms ?숈븞 異붽? 議곗옉???놁쓣 ?뚮쭔
   * ?꾩옱 吏???곸뿭???낆껜瑜??ㅼ떆 議고쉶?⑸땲??
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
     * ?댁쟾???좏깮???낆껜???꾨낫 ?뺣낫媛
     * ???낆껜 移대뱶???좉퉸 蹂댁씠吏 ?딅룄濡?珥덇린?뷀빀?덈떎.
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
              '?낆껜 ?꾩튂 ?뺣낫媛 ?놁뒿?덈떎.',
            ),
          ),
        );

      return;
    }

    /*
   * ?댁쟾???덉빟??吏???대룞 寃?됱씠 ?덈떎硫?痍⑥냼?⑸땲??
   *
   * 踰꾪듉?쇰줈 ?낆껜 ?꾩튂???대룞????諛쒖깮?섎뒗
   * ??viewport ?대깽?몃쭔 泥섎━?섎룄濡??⑸땲??
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
   * ???낆껜瑜??좏깮???뚮쭏???붿껌 踰덊샇瑜?利앷??쒗궢?덈떎.
   *
   * A ?낆껜瑜?議고쉶?섎뒗 ?꾩쨷 B ?낆껜瑜??좏깮?덉쓣 ??
   * ??쾶 ?꾩갑??A ?낆껜 ?묐떟??臾댁떆?섍린 ?꾪븳 媛믪엯?덈떎.
   */
    final requestSerial = ++_walkingRouteRequestSerial;

    /*
   * searchCenter媛 ?꾨땲???ㅼ젣 GPS ?꾩튂瑜??ъ슜?⑸땲??
   *
   * searchCenter???ъ슜?먭? 吏?꾨? ?吏곸씠硫?諛붾뚯?留?
   * location? ?ъ슜?먯쓽 ?ㅼ젣 ?꾩옱 ?꾩튂?낅땲??
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
     * ?붿껌 以??붾㈃???ロ삍嫄곕굹,
     * ?ㅻⅨ ?낆껜媛 ?좏깮?섏뿀嫄곕굹,
     * ??理쒖떊 ?붿껌???쒖옉??寃쎌슦?먮뒗
     * ?꾩옱 ?묐떟???붾㈃??諛섏쁺?섏? ?딆뒿?덈떎.
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
   * 吏꾪뻾 以묒씤 ?꾨낫 寃쎈줈 ?붿껌??臾댄슚?뷀빀?덈떎.
   *
   * ?묐떟???섏쨷???꾩갑?섎뜑?쇰룄
   * ?ロ엺 移대뱶??寃곌낵媛 ?ㅼ떆 ?곸슜?섏? ?딆뒿?덈떎.
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

    // ?쇱슦?곌? ???섏〈?깆쓣 ?꾨떖?섍린 ?꾧퉴吏??
    // 湲곗〈 ?붾㈃??濡쒖뺄 ?섑듃 ?숈옉???좎??⑸땲??
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
      _showFavoriteMessage('${store.name}??瑜? 李쒖뿉 異붽??덉뼱??');
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

    _showFavoriteMessage('李??곹깭瑜?蹂寃쏀븯吏 紐삵뻽?댁슂. ?좎떆 ???ㅼ떆 ?쒕룄??二쇱꽭??');
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
            '${store.name}??瑜? 李쒖뿉????젣?덉뼱??',
          ),
          action: SnackBarAction(
            label: '?섎룎由ш린',
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
   * ?ㅼ젣 愿??留ㅼ옣 而⑦듃濡ㅻ윭媛 ?꾩쭅 ?곌껐?섏? ?딆?
   * 濡쒖뺄 ?뚯뒪???곹깭??媛숈씠 泥섎━?⑸땲??
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
        '${store.name}??瑜? ?ㅼ떆 李쒗뻽?댁슂.',
      );

      return;
    }

    /*
   * SnackBar媛 ???덈뒗 ?숈븞 ?ㅻⅨ ?붾㈃?대굹 ?숈옉?먯꽌
   * ?대? ?ㅼ떆 李쒗뻽?ㅻ㈃ toggle???몄텧?섏? ?딆뒿?덈떎.
   *
   * ?ш린??臾댁“嫄?toggle?섎㈃ ?대? 異붽???李쒖씠
   * ?ㅼ떆 ??젣?????덇린 ?뚮Ц?낅땲??
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
        '${store.name}??瑜? ?ㅼ떆 李쒗뻽?댁슂.',
      );
      return;
    }

    if (result ==
        CustomerStoreInterestToggleResult.signInRequired) {
      _showFavoriteMessage(
        '濡쒓렇?몄씠 留뚮즺?섏뼱 李쒖쓣 ?섎룎由ъ? 紐삵뻽?댁슂.',
      );
      return;
    }

    _showFavoriteMessage(
      '李???젣瑜??섎룎由ъ? 紐삵뻽?댁슂. ?ㅼ떆 ?쒕룄??二쇱꽭??',
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
   * 沅뚰븳 ?덉슜 ?щ?? 愿怨꾩뾾??理쒖큹 ?덈궡???レ뒿?덈떎.
   *
   * ?덉슜?섎㈃ GPS ?꾩튂濡??ъ“?뚮릺硫?
   * ?덉슜?섏? ?딆쑝硫??대? 議고쉶??遺???꾩튂瑜?洹몃?濡??ъ슜?⑸땲??
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
      PermissionDecision.denied => '?꾩튂 沅뚰븳???덉슜?섏? ?딆븘 遺??吏??쓣 怨꾩냽 蹂댁뿬?쒕젮??',

      PermissionDecision.permanentlyDenied =>
        '?꾩옱 ?꾩튂瑜??ъ슜?섎젮硫?湲곌린 ?ㅼ젙?먯꽌 ?꾩튂 沅뚰븳???덉슜??二쇱꽭??',

      PermissionDecision.serviceDisabled => '湲곌린???꾩튂 ?쒕퉬?ㅺ? 爰쇱졇 ?덉뼱??',

      PermissionDecision.timeout => '?꾩옱 ?꾩튂瑜??뺤씤?섏? 紐삵빐 遺??吏??쓣 蹂댁뿬?쒕젮??',

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
                label: '?ㅼ젙',
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
                    Expanded(child: Text('?꾩옱 紐⑸줉?먯꽌 ?쇱튂?섎뒗 ?낆껜媛 ?놁뒿?덈떎.')),
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
                      ].join(' 쨌 '),
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
        tooltip: '?꾩옱 ?꾩튂濡??대룞',
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
                                ? '二쇱냼 ?뺣낫 以鍮?以?
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
                            store.resolvedSchedule.todayLabel(),
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
                                  '?꾨낫 寃쎈줈 ?뺤씤 以?..',
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
                            '?꾨낫 '
                                '${_formatDistance(walkingRoute!.distanceMeters)}'
                                ' 쨌 ??${walkingRoute!.durationMinutes}遺?,
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
                                '?꾨낫 ?뺣낫 ?ㅼ떆 ?쒕룄',
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
                            '?꾩옱 ?꾩튂瑜?耳쒕㈃ ?꾨낫 ?뺣낫瑜??뺤씤?????덉뼱??',
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
                tooltip: '?좏깮 ?낆껜 ?꾩튂濡??대룞',
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
                tooltip: favorite ? '愿???낆껜 ?댁젣' : '愿???낆껜 異붽?',
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
                tooltip: '?좏깮 ?リ린',
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
                        '??二쇰? ?낆껜瑜?李얠븘蹂쇨퉴??',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        '?꾩옱 ?꾩튂瑜??ъ슜?섎㈃ 媛源뚯슫 濡쒖뺄留덉폆怨?'
                        '?됱궗쨌?대깽?몃? 癒쇱? 蹂댁뿬?쒕젮??\n\n'
                        '?꾩튂瑜??ъ슜?섏? ?딆븘??遺??吏??쓣 '
                        '?섎윭蹂????덉뒿?덈떎.',
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
                            requestingLocation ? '?꾩옱 ?꾩튂 ?뺤씤 以?..' : '?꾩옱 ?꾩튂濡?蹂닿린',
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
                            '遺?곗뿉???섎윭蹂닿린',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '?꾩튂 ?ㅼ젙? 吏???꾨옒??GPS 踰꾪듉?먯꽌 '
                        '?몄젣???ㅼ떆 蹂寃쏀븷 ???덉뼱??',
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
                '??吏??쓽 ?낆껜瑜?李얘퀬 ?덉뼱??,
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
    'LOCAL_STORE' => '濡쒖뺄留덉폆',
    'EVENT_COMMERCE' => '?됱궗쨌?대깽??,
    _ => '?깅줉 ?낆껜',
  };
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
    'OPEN' => '?곸뾽 以?,
    'PRE_OPEN' => '?곸뾽 以鍮?,
    'CLOSED' => '?곸뾽 醫낅즺',
    'TEMPORARILY_CLOSED' => '?꾩떆 ?대Т',
    _ => businessStatus,
  };
}

String _formatDistance(int meters) {
  if (meters < 1000) {
    return '${meters}m';
  }

  return '${(meters / 1000).toStringAsFixed(1)}km';
}

