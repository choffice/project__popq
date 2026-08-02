//- 검색창
// - 로컬마켓/행사 필터
// - 선택한 업체
// - 하단 업체 카드

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../permissions/customer_permission_gateway.dart';
import 'store_discovery_controller.dart';
import 'store_discovery_repository.dart';
import 'kakao_store_map.dart';

class StoreDiscoveryScreen extends StatefulWidget {
  const StoreDiscoveryScreen({
    required this.repository,
    required this.permissionGateway,
    super.key,
  });

  final StoreDiscoveryRepository repository;
  final CustomerPermissionGateway permissionGateway;

  @override
  State<StoreDiscoveryScreen> createState() => _StoreDiscoveryScreenState();
}

class _StoreDiscoveryScreenState extends State<StoreDiscoveryScreen> {
  static const _accentColor = Color(0xFFB7FF00);
  static const _darkColor = Color(0xFF08110E);
  static const _greenColor = Color(0xFF17643E);

  static const _filters = [
    _StoreFilter(label: '전체', icon: Icons.apps_rounded, storeType: null),
    _StoreFilter(
      label: '로컬마켓',
      icon: Icons.storefront_rounded,
      storeType: 'LOCAL_STORE',
    ),
    _StoreFilter(
      label: '행사·이벤트',
      icon: Icons.celebration_rounded,
      storeType: 'EVENT_COMMERCE',
    ),
  ];

  late final StoreDiscoveryController _controller;

  final TextEditingController _queryController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  final Set<int> _favoriteStoreIds = {};

  CustomerStore? _selectedStore;

  String? _selectedStoreType;

  bool _showSuggestions = false;

  bool _showInitialLocationChoice = false;

  bool _requestingInitialLocation = false;

  Timer? _mapSearchDebounce;

  Object? _lastShownRefreshError;

  @override
  void initState() {
    super.initState();

    _controller = StoreDiscoveryController(
      repository: widget.repository,
      permissionGateway: widget.permissionGateway,
    )..addListener(_onControllerChanged);

    _initializeDiscovery();
  }

  @override
  void dispose() {
    _mapSearchDebounce?.cancel();

    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();

    _queryController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  Future<void> _initializeDiscovery() async {
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
    } else if (
    _controller.hasCompletedInitialLoad &&
        !_controller.isRefreshing &&
        !identical(
          _lastShownRefreshError,
          refreshError,
        )) {
      /*
     * 최초 연결 실패는 중앙 오류 화면에서 처리합니다.
     *
     * 이미 지도가 표시된 뒤의 재검색 실패만
     * SnackBar로 알려주고 기존 핀은 유지합니다.
     */
      _lastShownRefreshError = refreshError;

      WidgetsBinding.instance.addPostFrameCallback(
            (_) {
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                '새 지역의 업체를 불러오지 못했습니다. '
                    '기존 검색 결과를 유지합니다.',
              ),
            ),
          );
        },
      );
    }

    setState(() {
      final selectedStoreId =
          _selectedStore?.storeId;

      if (selectedStoreId == null) {
        return;
      }

      final selectedStoreStillExists =
      _filteredStores.any(
            (store) =>
        store.storeId == selectedStoreId,
      );

      if (!selectedStoreStillExists) {
        _selectedStore = null;
      }
    });
  }

  List<CustomerStore> get _filteredStores {
    if (_selectedStoreType == null) {
      return _controller.stores;
    }

    return _controller.stores
        .where((store) => store.storeType == _selectedStoreType)
        .toList();
  }

  List<CustomerStore> get _searchSuggestions {
    final query = _queryController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return const [];
    }

    return _filteredStores
        .where((store) {
          final nameMatches = store.name.toLowerCase().contains(query);

          final descriptionMatches =
              store.description?.toLowerCase().contains(query) ?? false;

          final addressMatches =
              store.address?.toLowerCase().contains(query) ?? false;

          final tagMatches = store.tags.any(
            (tag) => tag.toLowerCase().contains(query),
          );

          return nameMatches ||
              descriptionMatches ||
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
        KakaoStoreMap(
          stores: stores,
          currentLocation: _controller.location,
          searchCenter: _controller.searchCenter,
          selectedStoreId: _selectedStore?.storeId,
          onStoreSelected: _selectStore,
          onViewportIdle: _onMapViewportIdle,
        ),

        _buildStatusOverlay(stores),

        Positioned(top: 12, left: 12, right: 12, child: _buildTopControls()),

        Positioned(
          right: 16,
          bottom: _selectedStore == null ? 20 : 102,
          child: _CurrentLocationButton(
            active: _controller.location != null,
            onPressed: _useCurrentLocation,
          ),
        ),

        if (_selectedStore != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _SelectedStoreCard(
              store: _selectedStore!,
              favorite: _favoriteStoreIds.contains(_selectedStore!.storeId),
              favoriteUpdating: false,
              onFavoritePressed: _toggleFavorite,
              onDetailsPressed: _openStoreDetail,
              onClose: () {
                setState(() {
                  _selectedStore = null;
                });
              },
            ),
          ),

        if (_showInitialLocationChoice)
          Positioned.fill(
            child: _InitialLocationChoice(
              requestingLocation: _requestingInitialLocation,
              onUseCurrentLocation: _useCurrentLocationFromInitialChoice,
              onContinueWithBusan: _continueWithBusan,
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
          hintText: '업체명, 메뉴, 주소 검색',
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
            selectedStoreType: _selectedStoreType,
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

        if (_controller.isRefreshing &&
            !_showSuggestions) ...[
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
      DiscoveryStatus.data when filteredStores.isEmpty => const Center(
        child: _MapStatusCard(
          icon: Icons.filter_alt_off_rounded,
          message: '선택한 분류의 업체가 없습니다.',
        ),
      ),
      DiscoveryStatus.data => const SizedBox.shrink(),
    };
  }

  void _selectFilter(String? storeType) {
    setState(() {
      _selectedStoreType = storeType;
      _selectedStore = null;
      _showSuggestions = false;
    });

    _searchFocusNode.unfocus();
  }

  Future<void> _submitSearch(String value) async {
    _searchFocusNode.unfocus();

    setState(() {
      _showSuggestions = false;
      _selectedStore = null;
    });

    await _controller.search(query: value);

    if (!mounted) {
      return;
    }

    final stores = _filteredStores;

    if (stores.length == 1) {
      setState(() {
        _selectedStore = stores.first;
      });
    }
  }

  void _clearSearch() {
    _queryController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      _showSuggestions = false;
      _selectedStore = null;
    });

    _controller.search();
  }

  void _selectSearchSuggestion(CustomerStore store) {
    _queryController
      ..text = store.name
      ..selection = TextSelection.collapsed(offset: store.name.length);

    _searchFocusNode.unfocus();

    setState(() {
      _showSuggestions = false;
      _selectedStore = store;
    });
  }

  void _onMapViewportIdle(
      KakaoMapViewport viewport,
      ) {
    /*
   * 이전에 예약해 둔 지도 검색이 있다면 취소합니다.
   *
   * 사용자가 연속해서 지도를 움직일 때
   * 중간 위치마다 API를 호출하지 않기 위한 처리입니다.
   */
    _mapSearchDebounce?.cancel();

    /*
   * 지도를 다른 지역으로 옮기면 기존에 선택했던
   * 업체 카드는 닫습니다.
   */
    if (_selectedStore != null ||
        _showSuggestions) {
      setState(() {
        _selectedStore = null;
        _showSuggestions = false;
      });
    }

    _searchFocusNode.unfocus();

    /*
   * 지도가 멈춘 뒤 500ms 동안 추가 조작이 없을 때만
   * 현재 지도 영역의 업체를 다시 조회합니다.
   */
    _mapSearchDebounce = Timer(
      const Duration(milliseconds: 500),
          () async {
        if (!mounted) {
          return;
        }

        await _controller.searchAround(
          center: viewport.center,
          radiusKm: viewport.radiusKm,
          query: _queryController.text.trim(),
        );
      },
    );
  }

  void _selectStore(CustomerStore store) {
    _searchFocusNode.unfocus();

    setState(() {
      _showSuggestions = false;
      _selectedStore = store;
    });
  }

  void _toggleFavorite() {
    final storeId = _selectedStore?.storeId;

    if (storeId == null) {
      return;
    }

    setState(() {
      if (!_favoriteStoreIds.add(storeId)) {
        _favoriteStoreIds.remove(storeId);
      }
    });
  }

  void _openStoreDetail() {
    final storeId = _selectedStore?.storeId;

    if (storeId == null) {
      return;
    }

    context.push('${CustomerRoutes.stores}/$storeId');
  }

  Future<void> _useCurrentLocationFromInitialChoice() async {
    if (_requestingInitialLocation) {
      return;
    }

    _mapSearchDebounce?.cancel();

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

    final decision =
    await _controller.useCurrentLocation(
      query: _queryController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (decision == PermissionDecision.granted) {
      return;
    }

    _showLocationDecisionMessage(decision);
  }

  void _showLocationDecisionMessage(PermissionDecision decision) {
    final message = switch (decision) {
      PermissionDecision.denied =>
      '위치 권한을 허용하지 않아 부산 지역을 계속 보여드려요.',

      PermissionDecision.permanentlyDenied =>
      '현재 위치를 사용하려면 기기 설정에서 위치 권한을 허용해 주세요.',

      PermissionDecision.serviceDisabled =>
      '기기의 위치 서비스가 꺼져 있어요.',

      PermissionDecision.timeout =>
      '현재 위치를 확인하지 못해 부산 지역을 보여드려요.',

      PermissionDecision.granted => '',
    };

    if (message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
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

class _StoreFilter {
  const _StoreFilter({
    required this.label,
    required this.icon,
    required this.storeType,
  });

  final String label;
  final IconData icon;
  final String? storeType;
}

class _StoreFilterBar extends StatelessWidget {
  const _StoreFilterBar({
    required this.filters,
    required this.selectedStoreType,
    required this.onSelected,
  });

  static const _accentColor = Color(0xFFB7FF00);
  static const _darkColor = Color(0xFF08110E);

  final List<_StoreFilter> filters;
  final String? selectedStoreType;
  final ValueChanged<String?> onSelected;

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
            final selected = filter.storeType == selectedStoreType;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () {
                    onSelected(filter.storeType);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
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
                          size: 17,
                          color: selected
                              ? _darkColor
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            filter.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? _darkColor : null,
                              fontSize: 11,
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

  static const _accentColor = Color(0xFFB7FF00);
  static const _darkColor = Color(0xFF08110E);

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
                    leading: CircleAvatar(
                      backgroundColor: _accentColor,
                      foregroundColor: _darkColor,
                      child: Icon(_storeTypeIcon(store.storeType)),
                    ),
                    title: Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        _storeTypeLabel(store.storeType),
                        if (store.address != null) store.address!,
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

class _DiscoveryMapStage extends StatelessWidget {
  const _DiscoveryMapStage({
    required this.stores,
    required this.selectedStoreId,
    required this.onStoreSelected,
  });

  static const _fallbackMarkerPositions = [
    Alignment(-0.62, -0.35),
    Alignment(0.47, -0.28),
    Alignment(-0.10, 0.02),
    Alignment(0.59, 0.27),
    Alignment(-0.52, 0.39),
    Alignment(0.03, 0.60),
    Alignment(-0.67, 0.68),
    Alignment(0.55, 0.65),
  ];

  final List<CustomerStore> stores;
  final int? selectedStoreId;
  final ValueChanged<CustomerStore> onStoreSelected;

  @override
  Widget build(BuildContext context) {
    final visibleStores = stores.take(_fallbackMarkerPositions.length).toList();

    final markerPositions = _createMarkerPositions(visibleStores);

    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < visibleStores.length; index++)
          Align(
            alignment: markerPositions[index],
            child: _StoreMapMarker(
              store: visibleStores[index],
              selected: visibleStores[index].storeId == selectedStoreId,
              onPressed: () {
                onStoreSelected(visibleStores[index]);
              },
            ),
          ),

        Positioned(
          left: 14,
          bottom: 14,
          child: Material(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 15),
                  SizedBox(width: 5),
                  Text(
                    '카카오맵 연결 영역',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Alignment> _createMarkerPositions(List<CustomerStore> stores) {
    if (stores.isEmpty) {
      return const [];
    }

    final storesWithCoordinates = stores.where(
      (store) => store.latitude != null && store.longitude != null,
    );

    if (storesWithCoordinates.length < 2) {
      return List.generate(
        stores.length,
        (index) =>
            _fallbackMarkerPositions[index % _fallbackMarkerPositions.length],
      );
    }

    var minLatitude = storesWithCoordinates.first.latitude!;
    var maxLatitude = storesWithCoordinates.first.latitude!;
    var minLongitude = storesWithCoordinates.first.longitude!;
    var maxLongitude = storesWithCoordinates.first.longitude!;

    for (final store in storesWithCoordinates) {
      final latitude = store.latitude!;
      final longitude = store.longitude!;

      if (latitude < minLatitude) {
        minLatitude = latitude;
      }

      if (latitude > maxLatitude) {
        maxLatitude = latitude;
      }

      if (longitude < minLongitude) {
        minLongitude = longitude;
      }

      if (longitude > maxLongitude) {
        maxLongitude = longitude;
      }
    }

    final latitudeRange = maxLatitude - minLatitude;
    final longitudeRange = maxLongitude - minLongitude;

    if (latitudeRange == 0 || longitudeRange == 0) {
      return List.generate(
        stores.length,
        (index) =>
            _fallbackMarkerPositions[index % _fallbackMarkerPositions.length],
      );
    }

    return List.generate(stores.length, (index) {
      final store = stores[index];
      final latitude = store.latitude;
      final longitude = store.longitude;

      if (latitude == null || longitude == null) {
        return _fallbackMarkerPositions[index %
            _fallbackMarkerPositions.length];
      }

      final normalizedX = (longitude - minLongitude) / longitudeRange;

      final normalizedY = (latitude - minLatitude) / latitudeRange;

      final x = (normalizedX * 1.4 - 0.7).clamp(-0.78, 0.78).toDouble();

      final y = (0.65 - normalizedY * 1.25).clamp(-0.68, 0.72).toDouble();

      return Alignment(x, y);
    });
  }
}

class _StoreMapMarker extends StatelessWidget {
  const _StoreMapMarker({
    required this.store,
    required this.selected,
    required this.onPressed,
  });

  static const _accentColor = Color(0xFFB7FF00);
  static const _darkColor = Color(0xFF08110E);

  final CustomerStore store;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? _accentColor : _darkColor;

    final foregroundColor = selected ? _darkColor : Colors.white;

    return Material(
      color: backgroundColor,
      elevation: selected ? 9 : 4,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 165),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _storeTypeIcon(store.storeType),
                  size: 17,
                  color: foregroundColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

class _SelectedStoreCard extends StatelessWidget {
  const _SelectedStoreCard({
    required this.store,
    required this.favorite,
    required this.favoriteUpdating,
    required this.onFavoritePressed,
    required this.onDetailsPressed,
    required this.onClose,
  });

  static const _accentColor = Color(0xFFB7FF00);
  static const _darkColor = Color(0xFF08110E);
  static const _greenColor = Color(0xFF17643E);

  final CustomerStore store;
  final bool favorite;
  final bool favoriteUpdating;
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _storeTypeIcon(store.storeType),
                  color: _darkColor,
                  size: 24,
                ),
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
                            store.address ?? '주소 정보 준비 중',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (store.distanceMeters != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatDistance(store.distanceMeters!),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

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
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
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
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          icon: requestingLocation
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _darkColor,
                            ),
                          )
                              : const Icon(
                            Icons.my_location_rounded,
                          ),
                          label: Text(
                            requestingLocation
                                ? '현재 위치 확인 중...'
                                : '현재 위치로 보기',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          child: const Text(
                            '부산에서 둘러보기',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '위치 설정은 지도 아래의 GPS 버튼에서 '
                            '언제든 다시 변경할 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
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

class _MapRefreshIndicator
    extends StatelessWidget {
  const _MapRefreshIndicator();

  static const _darkColor =
  Color(0xFF08110E);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Theme.of(context)
            .colorScheme
            .surface
            .withOpacity(0.94),
        borderRadius:
        BorderRadius.circular(999),
        elevation: 3,
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child:
                CircularProgressIndicator(
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

class _TemporaryMapPainter extends CustomPainter {
  const _TemporaryMapPainter({required this.darkMode});

  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundColor = darkMode
        ? const Color(0xFF17201D)
        : const Color(0xFFE7E6DF);

    final blockColor = darkMode
        ? const Color(0xFF27312E)
        : const Color(0xFFD2D1C9);

    final parkColor = darkMode
        ? const Color(0xFF1E3A2B)
        : const Color(0xFFC9DDC4);

    final roadColor = darkMode
        ? const Color(0xFF3D4744)
        : const Color(0xFFF8F7F2);

    final roadOutlineColor = darkMode
        ? const Color(0xFF121917)
        : const Color(0xFFBDBCB5);

    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final blockPaint = Paint()..color = blockColor;

    for (var row = 0; row < 7; row++) {
      for (var column = 0; column < 5; column++) {
        final left = column * size.width / 4.3 - 18;
        final top = row * size.height / 6.2 - 10;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, size.width * 0.17, size.height * 0.09),
            const Radius.circular(9),
          ),
          blockPaint,
        );
      }
    }

    final parkPaint = Paint()..color = parkColor;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.05,
          size.height * 0.18,
          size.width * 0.27,
          size.height * 0.19,
        ),
        const Radius.circular(28),
      ),
      parkPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.66,
          size.height * 0.57,
          size.width * 0.29,
          size.height * 0.23,
        ),
        const Radius.circular(28),
      ),
      parkPaint,
    );

    final roadOutlinePaint = Paint()
      ..color = roadOutlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 29
      ..strokeCap = StrokeCap.round;

    final roadPaint = Paint()
      ..color = roadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 21
      ..strokeCap = StrokeCap.round;

    final mainRoad = Path()
      ..moveTo(-30, size.height * 0.78)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.67,
        size.width * 0.58,
        size.height * 0.43,
        size.width + 30,
        size.height * 0.22,
      );

    canvas
      ..drawPath(mainRoad, roadOutlinePaint)
      ..drawPath(mainRoad, roadPaint);

    final verticalRoad = Path()
      ..moveTo(size.width * 0.25, -30)
      ..cubicTo(
        size.width * 0.29,
        size.height * 0.25,
        size.width * 0.36,
        size.height * 0.67,
        size.width * 0.43,
        size.height + 30,
      );

    canvas
      ..drawPath(verticalRoad, roadOutlinePaint)
      ..drawPath(verticalRoad, roadPaint);

    final rightRoad = Path()
      ..moveTo(size.width * 0.73, -30)
      ..cubicTo(
        size.width * 0.64,
        size.height * 0.33,
        size.width * 0.69,
        size.height * 0.69,
        size.width * 0.79,
        size.height + 30,
      );

    canvas
      ..drawPath(rightRoad, roadOutlinePaint)
      ..drawPath(rightRoad, roadPaint);
  }

  @override
  bool shouldRepaint(covariant _TemporaryMapPainter oldDelegate) {
    return oldDelegate.darkMode != darkMode;
  }
}

String _storeTypeLabel(String storeType) {
  return switch (storeType) {
    'LOCAL_STORE' => '로컬마켓',
    'EVENT_COMMERCE' => '행사·이벤트',
    _ => '등록 업체',
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
    'OPEN' => '영업 중',
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
