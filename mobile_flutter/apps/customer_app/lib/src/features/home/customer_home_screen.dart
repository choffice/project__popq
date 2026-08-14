import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../discovery/store_discovery_repository.dart';
import '../orders/customer_order_repository.dart';
import '../permissions/customer_permission_gateway.dart';
import 'customer_home_content.dart';
import 'customer_home_controller.dart';
import 'customer_location_repository.dart';


class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    required this.storeDiscoveryRepository,
    required this.orderRepository,
    required this.sessionController,
    required this.permissionGateway,
    required this.locationRepository,
    this.preloadedController,
    super.key,
  });

  final StoreDiscoveryRepository storeDiscoveryRepository;
  final CustomerOrderRepository orderRepository;
  final SessionController sessionController;
  final CustomerPermissionGateway permissionGateway;
  final CustomerLocationRepository locationRepository;

  /// 앱 부팅 시 스플래시 화면과 함께 미리 로딩을 시작한 컨트롤러입니다.
  ///
  /// 전달되면 이 화면은 새 컨트롤러를 만들지 않고 그대로 사용하며,
  /// 소유권(dispose 책임)도 이 화면이 아니라 앱 상위에 남습니다.
  final CustomerHomeController? preloadedController;

  @override
  State<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState
    extends State<CustomerHomeScreen> {
  late CustomerHomeController _controller;
  bool _ownsController = true;

  /// 현재 선택된 카테고리 필터입니다.
  ///
  /// 백엔드 카테고리 필터 API가 아직 없어 화면 표시 용도로만 사용합니다.
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(
      CustomerHomeScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    final dependenciesChanged =
        !identical(
          oldWidget.storeDiscoveryRepository,
          widget.storeDiscoveryRepository,
        ) ||
            !identical(
              oldWidget.orderRepository,
              widget.orderRepository,
            ) ||
            !identical(
              oldWidget.sessionController,
              widget.sessionController,
            ) ||
            !identical(
              oldWidget.permissionGateway,
              widget.permissionGateway,
            ) ||
            !identical(
              oldWidget.locationRepository,
              widget.locationRepository,
            ) ||
            !identical(
              oldWidget.preloadedController,
              widget.preloadedController,
            );

    if (!dependenciesChanged) {
      return;
    }

    if (_ownsController) {
      _controller.dispose();
    }

    _createController();
  }

  void _createController() {
    final preloadedController = widget.preloadedController;

    if (preloadedController != null) {
      _controller = preloadedController;
      _ownsController = false;
      return;
    }

    _controller = CustomerHomeController(
      widget.storeDiscoveryRepository,
      widget.orderRepository,
      widget.sessionController,
      widget.permissionGateway,
      widget.locationRepository,
    );
    _ownsController = true;

    unawaited(_controller.load());
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showLocationPicker() async {
    final snapshot = _controller.snapshot;

    if (!mounted || snapshot == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _LocationPickerSheet(
          controller: _controller,
          currentLocationLabel:
              snapshot.currentLocationLabel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final snapshot = _controller.snapshot;

        if (snapshot == null) {
          return _InitialLoadingView(
            onRefresh: _controller.refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.sm,
              PopqSpacing.md,
              PopqSpacing.xl,
            ),
            children: [
              if (_controller.status ==
                  CustomerHomeStatus.loading) ...[
                const LinearProgressIndicator(
                  minHeight: 3,
                ),
                const SizedBox(
                  height: PopqSpacing.md,
                ),
              ],

              _LocationHeader(
                locationLabel:
                snapshot.currentLocationLabel,
                onLocationPressed:
                    _showLocationPicker,
                onCartPressed: () {
                  context.push(
                    CustomerRoutes.cart,
                  );
                },
              ),

              const SizedBox(
                height: PopqSpacing.md,
              ),

              _HomeSearchBar(
                onTap: () {
                  context.go(
                    CustomerRoutes.discover,
                  );
                },
              ),

              const SizedBox(
                height: PopqSpacing.lg,
              ),

              const _SectionHeader(
                eyebrow: 'FEATURED',
                title: '이번 주 추천 이벤트',
                description:
                '지금 놓치면 아쉬운 이벤트를 모았어요.',
              ),

              const SizedBox(
                height: PopqSpacing.md,
              ),

              _FeatureEventCarousel(
                banners: snapshot.featureBanners,
              ),

              const SizedBox(
                height: PopqSpacing.xl,
              ),

              _SectionHeader(
                eyebrow: 'RANKING',
                title: '인기 랭킹 TOP 5',
                description:
                '${snapshot.regionLabel}에서 지금 가장 인기 있는 곳을 모았어요.',
              ),

              const SizedBox(
                height: PopqSpacing.sm,
              ),

              _CategoryTabsRow(
                selectedIndex:
                _selectedCategoryIndex,
                onSelected: (index) {
                  setState(() {
                    _selectedCategoryIndex =
                        index;
                  });
                },
              ),

              const SizedBox(
                height: PopqSpacing.md,
              ),

              SizedBox(
                height: 216,
                child: snapshot.recommendedStores.isNotEmpty
                    ? ListView.separated(
                  scrollDirection:
                  Axis.horizontal,
                  itemCount:
                  snapshot.recommendedStores.length,
                  separatorBuilder:
                      (context, index) {
                    return const SizedBox(
                      width: PopqSpacing.sm,
                    );
                  },
                  itemBuilder:
                      (context, index) {
                    final store =
                    snapshot
                        .recommendedStores[index];

                    return _RankingStoreCard(
                      rank: index + 1,
                      store: store,
                      onTap: () {
                        context.push(
                          '${CustomerRoutes.stores}/'
                              '${store.storeId}',
                        );
                      },
                    );
                  },
                )
                    : snapshot.regionLabel == '부산'
                    ? ListView.separated(
                  scrollDirection:
                  Axis.horizontal,
                  itemCount: snapshot
                      .temporaryRecommendations.length,
                  separatorBuilder:
                      (context, index) {
                    return const SizedBox(
                      width: PopqSpacing.sm,
                    );
                  },
                  itemBuilder:
                      (context, index) {
                    return _RankingTemporaryCard(
                      rank: index + 1,
                      item: snapshot
                          .temporaryRecommendations[index],
                    );
                  },
                )
                    : _RegionContentEmptyCard(
                  regionLabel: snapshot.regionLabel,
                  message: '등록된 인기 매장이 아직 없어요.',
                ),
              ),

              const SizedBox(
                height: PopqSpacing.xl,
              ),

              _SectionHeader(
                eyebrow: 'EVENT',
                title: '진행 중인 이벤트',
                description:
                '${snapshot.regionLabel}에서 지금만 만날 수 있는 공간을 확인해 보세요.',
              ),

              const SizedBox(
                height: PopqSpacing.md,
              ),

              SizedBox(
                height: 216,
                child: snapshot.eventStores.isNotEmpty
                    ? ListView.separated(
                  scrollDirection:
                  Axis.horizontal,
                  itemCount:
                  snapshot.eventStores.length,
                  separatorBuilder:
                      (context, index) {
                    return const SizedBox(
                      width: PopqSpacing.sm,
                    );
                  },
                  itemBuilder:
                      (context, index) {
                    final store =
                    snapshot
                        .eventStores[index];

                    return _OngoingEventStoreCard(
                      store: store,
                      onTap: () {
                        context.push(
                          '${CustomerRoutes.stores}/'
                              '${store.storeId}',
                        );
                      },
                    );
                  },
                )
                    : snapshot.regionLabel == '부산'
                    ? ListView.separated(
                  scrollDirection:
                  Axis.horizontal,
                  itemCount: snapshot
                      .temporaryPopups.length,
                  separatorBuilder:
                      (context, index) {
                    return const SizedBox(
                      width: PopqSpacing.sm,
                    );
                  },
                  itemBuilder:
                      (context, index) {
                    return _OngoingEventTemporaryCard(
                      item: snapshot
                          .temporaryPopups[index],
                    );
                  },
                )
                    : _RegionContentEmptyCard(
                  regionLabel: snapshot.regionLabel,
                  message: '진행 중인 이벤트가 아직 없어요.',
                ),
              ),

              if (snapshot.activeOrder != null) ...[
                const SizedBox(
                  height: PopqSpacing.xl,
                ),
                _ActiveOrderCard(
                  order: snapshot.activeOrder!,
                  onTap: () {
                    context.push(
                      '${CustomerRoutes.orders}/'
                          '${snapshot.activeOrder!.orderPublicId}',
                    );
                  },
                ),
              ],

              if (snapshot.storeLoadFailed) ...[
                const SizedBox(
                  height: PopqSpacing.md,
                ),
                _LoadNotice(
                  message:
                  '매장 정보를 불러오지 못해 임시 콘텐츠를 표시하고 있어요.',
                  onRetry: _controller.refresh,
                ),
              ],

              const SizedBox(
                height: PopqSpacing.xl,
              ),

              const _SectionHeader(
                eyebrow: 'POPQ PICK',
                title: '지금 만날 수 있는 매장',
                description:
                '실제 Store API에서 불러온 매장을 소개해요.',
              ),

              const SizedBox(
                height: PopqSpacing.md,
              ),

              if (snapshot.featuredStore != null)
                _FeaturedStoreCard(
                  store: snapshot.featuredStore!,
                  onTap: () {
                    context.push(
                      '${CustomerRoutes.stores}/'
                          '${snapshot.featuredStore!.storeId}',
                    );
                  },
                )
              else
                _FeaturedStoreEmptyCard(
                  onRetry: _controller.refresh,
                ),

              const SizedBox(
                height: PopqSpacing.lg,
              ),

              for (final banner
              in snapshot.benefitBanners)
                _BenefitBanner(
                  banner: banner,
                  onTap: () {
                    context.go(
                      CustomerRoutes.profile,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InitialLoadingView extends StatelessWidget {
  const _InitialLoadingView({
    required this.onRefresh,
  });

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        children: const [
          SizedBox(height: 160),
          Center(
            child: CircularProgressIndicator(),
          ),
          SizedBox(
            height: PopqSpacing.md,
          ),
          Center(
            child: Text(
              '홈 정보를 불러오고 있어요.',
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({
    required this.locationLabel,
    required this.onLocationPressed,
    required this.onCartPressed,
  });

  final String locationLabel;
  final VoidCallback onLocationPressed;
  final VoidCallback onCartPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    final accentColor = isDark
        ? PopqPalette.lime
        : PopqPalette.forest;

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onLocationPressed,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: PopqSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '탐색 지역',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.xs,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 19,
                          color: accentColor,
                        ),
                        const SizedBox(
                          width: PopqSpacing.xs,
                        ),
                        Flexible(
                          child: Text(
                            locationLabel,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: theme
                                .textTheme.titleMedium
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 21,
                          color: mutedColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: PopqSpacing.sm),
        _RoundActionButton(
          tooltip: '장바구니',
          icon: Icons.shopping_bag_outlined,
          onPressed: onCartPressed,
        ),
      ],
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.controller,
    required this.currentLocationLabel,
  });

  final CustomerHomeController controller;
  final String currentLocationLabel;

  @override
  State<_LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState
    extends State<_LocationPickerSheet> {
  bool _usingCurrentLocation = false;
  String? _locationError;

  Future<void> _selectLocation(
    String locationLabel,
  ) async {
    await widget.controller.selectLocationLabel(
      locationLabel,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _useCurrentLocation() async {
    if (_usingCurrentLocation) {
      return;
    }

    setState(() {
      _usingCurrentLocation = true;
      _locationError = null;
    });

    final success =
        await widget.controller.useCurrentLocation();

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _usingCurrentLocation = false;
      _locationError =
          '현재 위치를 확인하지 못했어요. 위치 권한을 확인하거나 아래에서 지역을 직접 선택해 주세요.';
    });
  }

  String _displayLabel(String locationLabel) {
    if (locationLabel == '부산') {
      return '부산 전체';
    }

    return locationLabel
        .replaceFirst('부산 ', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final accentColor = isDark
        ? PopqPalette.lime
        : PopqPalette.forest;

    final cardColor = isDark
        ? PopqPalette.nightCard
        : PopqPalette.lightCard;

    final borderColor = isDark
        ? PopqPalette.nightBorder
        : PopqPalette.lightBorder;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    final recentLocations =
        widget.controller.recentLocationLabels;

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.lg,
              PopqSpacing.xs,
              PopqSpacing.lg,
              PopqSpacing.md,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '탐색 지역 설정',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '선택한 지역을 기준으로 홈의 매장과 이벤트를 보여줘요.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(
                    color: mutedColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                PopqSpacing.lg,
                0,
                PopqSpacing.lg,
                PopqSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Material(
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                      side: BorderSide(
                        color: borderColor,
                      ),
                    ),
                    child: InkWell(
                      onTap: _usingCurrentLocation
                          ? null
                          : _useCurrentLocation,
                      borderRadius:
                          BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          PopqSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(
                                  alpha: isDark ? 0.16 : 0.10,
                                ),
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.my_location_rounded,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(
                              width: PopqSpacing.md,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '현재 위치로 설정',
                                    style: theme
                                        .textTheme.titleSmall
                                        ?.copyWith(
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '휴대폰 위치를 기준으로 탐색해요',
                                    style: theme
                                        .textTheme.bodySmall
                                        ?.copyWith(
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_usingCurrentLocation)
                              SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: accentColor,
                                ),
                              )
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: mutedColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_locationError != null) ...[
                    const SizedBox(height: PopqSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(
                        PopqSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer
                            .withValues(alpha: 0.55),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Text(
                        _locationError!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(
                          color: theme
                              .colorScheme.onErrorContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  if (recentLocations.isNotEmpty) ...[
                    const SizedBox(height: PopqSpacing.lg),
                    Text(
                      '최근 설정 지역',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: PopqSpacing.sm),
                    Wrap(
                      spacing: PopqSpacing.sm,
                      runSpacing: PopqSpacing.sm,
                      children: [
                        for (final location
                            in recentLocations)
                          _LocationChoiceChip(
                            label: _displayLabel(location),
                            selected:
                                widget.currentLocationLabel ==
                                    location,
                            onTap: () =>
                                _selectLocation(location),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: PopqSpacing.lg),
                  Text(
                    '지역 직접 선택',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: PopqSpacing.xs),
                  Text(
                    '현재 POPQ 서비스 범위인 부산 지역에서 선택할 수 있어요.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(height: PopqSpacing.md),
                  Wrap(
                    spacing: PopqSpacing.sm,
                    runSpacing: PopqSpacing.sm,
                    children: [
                      for (final location
                          in CustomerHomeController
                              .supportedLocationLabels)
                        _LocationChoiceChip(
                          label: _displayLabel(location),
                          selected:
                              widget.currentLocationLabel ==
                                  location,
                          onTap: () =>
                              _selectLocation(location),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChoiceChip extends StatelessWidget {
  const _LocationChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final accentColor = isDark
        ? PopqPalette.lime
        : PopqPalette.forest;

    final borderColor = selected
        ? accentColor
        : (isDark
            ? PopqPalette.nightBorder
            : PopqPalette.lightBorder);

    final backgroundColor = selected
        ? accentColor.withValues(
            alpha: isDark ? 0.16 : 0.10,
          )
        : (isDark
            ? PopqPalette.nightCard
            : PopqPalette.lightCard);

    return Material(
      color: backgroundColor,
      shape: StadiumBorder(
        side: BorderSide(
          color: borderColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PopqSpacing.md,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: accentColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  color: selected ? accentColor : null,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionContentEmptyCard extends StatelessWidget {
  const _RegionContentEmptyCard({
    required this.regionLabel,
    required this.message,
  });

  final String regionLabel;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    final accentColor = isDark
        ? PopqPalette.lime
        : PopqPalette.forest;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? PopqPalette.nightCard
            : PopqPalette.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? PopqPalette.nightBorder
              : PopqPalette.lightBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_searching_rounded,
            color: accentColor,
            size: 30,
          ),
          const SizedBox(height: PopqSpacing.sm),
          Text(
            regionLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: mutedColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundActionButton
    extends StatelessWidget {
  const _RoundActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? PopqPalette.nightCard
          : PopqPalette.lightCard,
      shape: CircleBorder(
        side: BorderSide(
          color: isDark
              ? PopqPalette.nightBorder
              : PopqPalette.lightBorder,
        ),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _ActiveOrderCard
    extends StatelessWidget {
  const _ActiveOrderCard({
    required this.order,
    required this.onTap,
  });

  final CustomerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final foreground = isDark
        ? PopqPalette.nightText
        : Colors.white;

    final mutedForeground =
    foreground.withValues(
      alpha: 0.72,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(
            PopqSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? PopqPalette.nightElevated
                : PopqPalette.forest,
            borderRadius:
            BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? PopqPalette.lime
                  .withValues(
                alpha: 0.28,
              )
                  : PopqPalette.forest,
            ),
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: PopqPalette.lime,
                      borderRadius:
                      BorderRadius.circular(
                        999,
                      ),
                    ),
                    child: Text(
                      '진행 중 주문',
                      style: theme
                          .textTheme.labelMedium
                          ?.copyWith(
                        color:
                        PopqPalette.ink,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: foreground,
                  ),
                ],
              ),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              Text(
                _orderStatusTitle(
                  order.status,
                ),
                style: theme
                    .textTheme.titleLarge
                    ?.copyWith(
                  color: foreground,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: PopqSpacing.xs,
              ),
              Text(
                '${order.storeName} · '
                    '${_orderItemSummary(order)}',
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: theme
                    .textTheme.bodyMedium
                    ?.copyWith(
                  color: mutedForeground,
                ),
              ),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              ClipRRect(
                borderRadius:
                BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _orderProgress(
                    order.status,
                  ),
                  minHeight: 7,
                  backgroundColor:
                  foreground.withValues(
                    alpha: 0.18,
                  ),
                  valueColor:
                  const AlwaysStoppedAnimation(
                    PopqPalette.lime,
                  ),
                ),
              ),
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _orderStatusDescription(
                        order.status,
                      ),
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color:
                        mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: PopqSpacing.sm,
                  ),
                  Text(
                    _won(order.totalAmount),
                    style: theme
                        .textTheme.titleMedium
                        ?.copyWith(
                      color: foreground,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadNotice extends StatelessWidget {
  const _LoadNotice({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? PopqPalette.purple.withValues(
          alpha: 0.14,
        )
            : PopqPalette.coral.withValues(
          alpha: 0.1,
        ),
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? PopqPalette.purple
              .withValues(
            alpha: 0.35,
          )
              : PopqPalette.coral
              .withValues(
            alpha: 0.25,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
          ),
          const SizedBox(
            width: PopqSpacing.sm,
          ),
          Expanded(
            child: Text(
              message,
              style:
              theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '다시 시도',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader
    extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final accent = isDark
        ? PopqPalette.lime
        : PopqPalette.coral;

    final muted = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style:
          theme.textTheme.labelMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(
          height: PopqSpacing.xs,
        ),
        Text(
          title,
          style: theme
              .textTheme.headlineSmall
              ?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: PopqSpacing.xs,
        ),
        Text(
          description,
          style:
          theme.textTheme.bodySmall?.copyWith(
            color: muted,
          ),
        ),
      ],
    );
  }
}

class _FeaturedStoreCard
    extends StatelessWidget {
  const _FeaturedStoreCard({
    required this.store,
    required this.onTap,
  });

  final CustomerStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final foreground = isDark
        ? PopqPalette.nightText
        : Colors.white;

    final mutedForeground =
    foreground.withValues(
      alpha: 0.75,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(28),
        child: Ink(
          height: 244,
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                PopqPalette
                    .nightElevated,
                Color(0xFF25153E),
              ]
                  : const [
                PopqPalette.forest,
                Color(0xFF0E3328),
              ],
            ),
          ),
          child: Stack(
            children: [
              if (store.imageUrl?.trim().isNotEmpty == true) ...[
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.network(
                      store.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black26, Colors.black87],
                      ),
                    ),
                  ),
                ),
              ],
              Positioned(
                right: -22,
                bottom: -26,
                child: Icon(
                  _storeIcon(store),
                  size: 172,
                  color:
                  foreground.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.all(
                  PopqSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration:
                          BoxDecoration(
                            color:
                            PopqPalette.lime,
                            borderRadius:
                            BorderRadius
                                .circular(
                              999,
                            ),
                          ),
                          child: Text(
                            _businessStatusLabel(
                              store
                                  .businessStatus,
                            ),
                            style: theme
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                              color:
                              PopqPalette.ink,
                              fontWeight:
                              FontWeight
                                  .w900,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons
                              .arrow_forward_rounded,
                          color: foreground,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      store.name,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                        color: foreground,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.sm,
                    ),
                    Text(
                      store.description
                          ?.trim()
                          .isNotEmpty ==
                          true
                          ? store.description!
                          : 'POPQ에서 메뉴를 확인하고 바로 주문해 보세요.',
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme.bodyMedium
                          ?.copyWith(
                        color:
                        mutedForeground,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.md,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .location_on_outlined,
                          size: 18,
                          color:
                          PopqPalette.coral,
                        ),
                        const SizedBox(
                          width:
                          PopqSpacing.xs,
                        ),
                        Expanded(
                          child: Text(
                            store.address ??
                                '매장 상세에서 위치를 확인해 주세요.',
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color:
                              mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedStoreEmptyCard
    extends StatelessWidget {
  const _FeaturedStoreEmptyCard({
    required this.onRetry,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 44,
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '표시할 공개 매장이 아직 없어요.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(
              height: PopqSpacing.xs,
            ),
            const Text(
              '백엔드와 DB가 실행 중인지 확인한 뒤 다시 시도해 주세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: PopqSpacing.md,
            ),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                '다시 불러오기',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    return Material(
      color: isDark
          ? PopqPalette.nightCard
          : PopqPalette.lightCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(
            horizontal: PopqSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? PopqPalette.nightBorder
                  : PopqPalette.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: mutedColor,
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              Expanded(
                child: Text(
                  '식당, 행사, 팝업을 검색해 보세요',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(
                    color: mutedColor,
                  ),
                ),
              ),
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: mutedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _homeCategoryLabels = <String>[
  '전체',
  '식당',
  '팝업스토어',
  '플리마켓',
  '푸드트럭',
  '카페',
];

class _CategoryTabsRow extends StatelessWidget {
  const _CategoryTabsRow({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final accent = isDark
        ? PopqPalette.lime
        : PopqPalette.forest;

    final muted = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0;
          index < _homeCategoryLabels.length;
          index++) ...[
            if (index > 0)
              Container(
                width: 1,
                height: 14,
                margin:
                const EdgeInsets.symmetric(
                  horizontal: PopqSpacing.sm,
                ),
                color: muted.withValues(
                  alpha: 0.4,
                ),
              ),
            _CategoryTabButton(
              label: _homeCategoryLabels[index],
              selected: index == selectedIndex,
              accent: accent,
              muted: muted,
              onTap: () => onSelected(index),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTabButton extends StatelessWidget {
  const _CategoryTabButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: PopqSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(
                color: selected ? accent : muted,
                fontWeight: selected
                    ? FontWeight.w900
                    : FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: PopqSpacing.xs,
            ),
            AnimatedContainer(
              duration: const Duration(
                milliseconds: 150,
              ),
              height: 2,
              width: selected ? 20 : 0,
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureEventCarousel
    extends StatefulWidget {
  const _FeatureEventCarousel({
    required this.banners,
  });

  final List<CustomerHomeFeatureBanner> banners;

  @override
  State<_FeatureEventCarousel>
  createState() =>
      _FeatureEventCarouselState();
}

class _FeatureEventCarouselState
    extends State<_FeatureEventCarousel> {
  final _pageController = PageController();

  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (index) {
              setState(() {
                _page = index;
              });
            },
            itemBuilder: (context, index) {
              return _FeatureBannerSlide(
                banner: widget.banners[index],
              );
            },
          ),
        ),
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            for (var index = 0;
            index < widget.banners.length;
            index++)
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 200,
                ),
                margin:
                const EdgeInsets.symmetric(
                  horizontal: 3,
                ),
                width:
                index == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == _page
                      ? (isDark
                      ? PopqPalette.lime
                      : PopqPalette.forest)
                      : (isDark
                      ? PopqPalette
                      .nightBorder
                      : PopqPalette
                      .lightBorder),
                  borderRadius:
                  BorderRadius.circular(
                    999,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeatureBannerSlide
    extends StatelessWidget {
  const _FeatureBannerSlide({
    required this.banner,
  });

  final CustomerHomeFeatureBanner banner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        PopqSpacing.lg,
      ),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _temporaryVisualColors(
            banner.visualKind,
            isDark,
          ),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -22,
            child: Icon(
              _temporaryVisualIcon(
                banner.visualKind,
              ),
              size: 140,
              color: Colors.white.withValues(
                alpha: 0.12,
              ),
            ),
          ),
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            mainAxisAlignment:
            MainAxisAlignment.end,
            children: [
              Text(
                banner.title,
                style: theme
                    .textTheme.headlineSmall
                    ?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: PopqSpacing.xs,
              ),
              Text(
                banner.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  color: Colors.white
                      .withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(
                height: PopqSpacing.md,
              ),
              Row(
                children: [
                  const Icon(
                    Icons.event_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(
                    width: PopqSpacing.xs,
                  ),
                  Text(
                    banner.periodLabel,
                    style: theme
                        .textTheme.bodySmall
                        ?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(
                    width: PopqSpacing.sm,
                  ),
                  const Icon(
                    Icons.place_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(
                    width: PopqSpacing.xs,
                  ),
                  Expanded(
                    child: Text(
                      banner.locationLabel,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeStoreThumbnail extends StatelessWidget {
  const _HomeStoreThumbnail({
    required this.height,
    required this.width,
    required this.imageUrl,
    required this.fallbackColor,
    required this.fallbackIcon,
    required this.fallbackIconColor,
    this.borderRadius = 0,
    this.fallbackIconSize = 30,
  });

  final double height;
  final double width;
  final String? imageUrl;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final Color fallbackIconColor;
  final double borderRadius;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
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
      color: fallbackColor,
      child: Center(
        child: Icon(
          fallbackIcon,
          color: fallbackIconColor,
          size: fallbackIconSize,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
  });

  final int rank;

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isTop
            ? PopqPalette.coral
            : PopqPalette.ink.withValues(
          alpha: 0.72,
        ),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RankingStoreCard
    extends StatelessWidget {
  const _RankingStoreCard({
    required this.rank,
    required this.store,
    required this.onTap,
  });

  final int rank;
  final CustomerStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(
              PopqSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _HomeStoreThumbnail(
                      height: 110,
                      width: double.infinity,
                      imageUrl: store.imageUrl,
                      borderRadius: 16,
                      fallbackColor: isDark
                          ? PopqPalette.purple.withValues(alpha: 0.2)
                          : PopqPalette.lime.withValues(alpha: 0.45),
                      fallbackIcon: _storeIcon(store),
                      fallbackIconColor: isDark
                          ? PopqPalette.lime
                          : PopqPalette.forest,
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _RankBadge(
                        rank: rank,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: PopqSpacing.xs,
                ),
                Text(
                  store.name,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: theme
                      .textTheme.titleMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                Text(
                  _storeCategoryLabel(store),
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingTemporaryCard
    extends StatelessWidget {
  const _RankingTemporaryCard({
    required this.rank,
    required this.item,
  });

  final int rank;
  final CustomerHomeRecommendedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(
            PopqSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                        _temporaryVisualColors(
                          item.visualKind,
                          isDark,
                        ),
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Icon(
                      _temporaryVisualIcon(
                        item.visualKind,
                      ),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _RankBadge(
                      rank: rank,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: PopqSpacing.xs,
              ),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme
                    .textTheme.titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                item.categoryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                theme.textTheme.bodySmall,
              ),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: PopqPalette.coral,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    item.rating
                        .toStringAsFixed(1),
                    style: theme
                        .textTheme.bodySmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                  if (item.visitLabel !=
                      null) ...[
                    const SizedBox(
                      width: PopqSpacing.xs,
                    ),
                    Expanded(
                      child: Text(
                        item.visitLabel!,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DDayBadge extends StatelessWidget {
  const _DDayBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: PopqPalette.ink.withValues(
          alpha: 0.72,
        ),
        borderRadius:
        BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _OngoingEventStoreCard
    extends StatelessWidget {
  const _OngoingEventStoreCard({
    required this.store,
    required this.onTap,
  });

  final CustomerStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _HomeStoreThumbnail(
                    height: 110,
                    width: double.infinity,
                    imageUrl: store.imageUrl,
                    fallbackColor: isDark
                        ? PopqPalette.purple
                        : PopqPalette.coral,
                    fallbackIcon: Icons.local_activity_rounded,
                    fallbackIconColor: Colors.white,
                    fallbackIconSize: 52,
                  ),
                  const Positioned(
                    left: PopqSpacing.sm,
                    top: PopqSpacing.sm,
                    child: _DDayBadge(
                      label: '진행중',
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(
                  PopqSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme.titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.xs,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 16,
                          color: mutedColor,
                        ),
                        const SizedBox(
                          width:
                          PopqSpacing.xs,
                        ),
                        Expanded(
                          child: Text(
                            store.address ??
                                '매장 상세에서 위치 확인',
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OngoingEventTemporaryCard
    extends StatelessWidget {
  const _OngoingEventTemporaryCard({
    required this.item,
  });

  final CustomerHomePopupItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final mutedColor = isDark
        ? PopqPalette.nightMutedText
        : PopqPalette.lightMutedText;

    return SizedBox(
      width: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                      _temporaryVisualColors(
                        item.visualKind,
                        isDark,
                      ),
                    ),
                  ),
                  child: Icon(
                    _temporaryVisualIcon(
                      item.visualKind,
                    ),
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  left: PopqSpacing.sm,
                  top: PopqSpacing.sm,
                  child: _DDayBadge(
                    label: item.dDayLabel ??
                        item.badgeLabel,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(
                PopqSpacing.md,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: theme
                        .textTheme.titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: PopqSpacing.xs,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 16,
                        color: mutedColor,
                      ),
                      const SizedBox(
                        width: PopqSpacing.xs,
                      ),
                      Text(
                        item.periodLabel,
                        style: theme
                            .textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.place_rounded,
                        size: 16,
                        color: mutedColor,
                      ),
                      const SizedBox(
                        width: PopqSpacing.xs,
                      ),
                      Expanded(
                        child: Text(
                          item.locationLabel,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: theme
                              .textTheme
                              .bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitBanner
    extends StatelessWidget {
  const _BenefitBanner({
    required this.banner,
    required this.onTap,
  });

  final CustomerHomeBenefitBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final foreground = isDark
        ? PopqPalette.nightText
        : PopqPalette.ink;

    final mutedForeground =
    foreground.withValues(
      alpha: 0.68,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(
            PopqSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? PopqPalette.purple
                .withValues(
              alpha: 0.28,
            )
                : PopqPalette.coral
                .withValues(
              alpha: 0.13,
            ),
            borderRadius:
            BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? PopqPalette.purple
                  .withValues(
                alpha: 0.48,
              )
                  : PopqPalette.coral
                  .withValues(
                alpha: 0.28,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.eyebrow,
                      style: theme
                          .textTheme.labelMedium
                          ?.copyWith(
                        color: isDark
                            ? PopqPalette.lime
                            : PopqPalette.coral,
                        fontWeight:
                        FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.sm,
                    ),
                    Text(
                      banner.title,
                      style: theme
                          .textTheme.titleLarge
                          ?.copyWith(
                        color: foreground,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.sm,
                    ),
                    Text(
                      banner.description,
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
                        color:
                        mutedForeground,
                      ),
                    ),
                    const SizedBox(
                      height: PopqSpacing.md,
                    ),
                    Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        Text(
                          banner.actionLabel,
                          style: theme
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                            color: isDark
                                ? PopqPalette
                                .lime
                                : PopqPalette
                                .forest,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),
                        const SizedBox(
                          width:
                          PopqSpacing.xs,
                        ),
                        Icon(
                          Icons
                              .arrow_forward_rounded,
                          size: 18,
                          color: isDark
                              ? PopqPalette.lime
                              : PopqPalette
                              .forest,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: PopqSpacing.md,
              ),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: isDark
                      ? PopqPalette.lime
                      .withValues(
                    alpha: 0.14,
                  )
                      : PopqPalette.lime
                      .withValues(
                    alpha: 0.55,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _temporaryVisualIcon(
                    banner.visualKind,
                  ),
                  size: 38,
                  color: isDark
                      ? PopqPalette.lime
                      : PopqPalette.forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _businessStatusLabel(
    String status,
    ) {
  return switch (status) {
    'OPEN' => '영업 중',
    'PRE_OPEN' => '준비중',
    _ => status,
  };
}

String _storeCategoryLabel(
    CustomerStore store,
    ) {
  final String category =
      store.representativeCategory?.trim() ?? '';

  if (category.isNotEmpty) {
    return category;
  }

  if (store.tags.isNotEmpty) {
    return store.tags
        .take(3)
        .map(_tagLabel)
        .join(' · ');
  }

  return store.storeType ==
      'EVENT_COMMERCE'
      ? '팝업 · 행사형 매장'
      : '로컬 매장';
}

String _tagLabel(String tag) {
  return switch (tag.toLowerCase()) {
    'coffee' => '커피',
    'cafe' => '카페',
    'dessert' => '디저트',
    'local' => '로컬',
    'event' => '이벤트',
    'food' => '푸드',
    _ => tag,
  };
}

IconData _storeIcon(
    CustomerStore store,
    ) {
  final normalizedTags = store.tags
      .map(
        (tag) => tag.toLowerCase(),
  )
      .toSet();

  if (normalizedTags.contains(
    'coffee',
  ) ||
      normalizedTags.contains(
        'cafe',
      )) {
    return Icons.local_cafe_rounded;
  }

  if (normalizedTags.contains(
    'dessert',
  )) {
    return Icons.cake_rounded;
  }

  if (store.storeType ==
      'EVENT_COMMERCE') {
    return Icons.local_activity_rounded;
  }

  return Icons.storefront_rounded;
}

String _orderStatusTitle(
    String status,
    ) {
  return switch (status) {
    'PLACED' =>
    '주문 접수를 기다리고 있어요',
    'ACCEPTED' =>
    '매장에서 주문을 확인했어요',
    'PREPARING' =>
    '주문 상품을 준비하고 있어요',
    'READY' =>
    '픽업 준비가 완료됐어요',
    _ => '주문이 진행 중이에요',
  };
}

String _orderStatusDescription(
    String status,
    ) {
  return switch (status) {
    'PLACED' =>
    '매장 접수 후 준비가 시작됩니다.',
    'ACCEPTED' =>
    '곧 상품 준비가 시작됩니다.',
    'PREPARING' =>
    '준비가 끝나면 바로 알려드릴게요.',
    'READY' =>
    '매장에서 상품을 수령해 주세요.',
    _ =>
    '주문 상세에서 최신 상태를 확인해 주세요.',
  };
}

double _orderProgress(
    String status,
    ) {
  return switch (status) {
    'PLACED' => 0.25,
    'ACCEPTED' => 0.5,
    'PREPARING' => 0.75,
    'READY' => 1,
    _ => 0.1,
  };
}

String _orderItemSummary(
    CustomerOrder order,
    ) {
  if (order.items.isEmpty) {
    return '주문 상품 확인';
  }

  final firstItem =
      order.items.first;

  final remainingCount =
      order.items.length - 1;

  if (remainingCount <= 0) {
    return '${firstItem.productName} '
        '${firstItem.quantity}개';
  }

  return '${firstItem.productName} '
      '외 $remainingCount개';
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0;
  index < digits.length;
  index++) {
    if (index > 0 &&
        (digits.length - index) % 3 ==
            0) {
      buffer.write(',');
    }

    buffer.write(
      digits[index],
    );
  }

  return '$buffer원';
}

IconData _temporaryVisualIcon(
    CustomerHomeVisualKind kind,
    ) {
  return switch (kind) {
    CustomerHomeVisualKind.taco =>
    Icons.lunch_dining_rounded,
    CustomerHomeVisualKind.dessert =>
    Icons.cake_rounded,
    CustomerHomeVisualKind
        .koreanFood =>
    Icons.rice_bowl_rounded,
    CustomerHomeVisualKind.steak =>
    Icons.restaurant_rounded,
    CustomerHomeVisualKind
        .membership =>
    Icons.loyalty_rounded,
    CustomerHomeVisualKind
        .popupMarket =>
    Icons.storefront_rounded,
    CustomerHomeVisualKind.cafe =>
    Icons.local_cafe_rounded,
  };
}

List<Color> _temporaryVisualColors(
    CustomerHomeVisualKind kind,
    bool isDark,
    ) {
  if (isDark) {
    return switch (kind) {
      CustomerHomeVisualKind.taco =>
      const [
        PopqPalette.purple,
        PopqPalette.nightElevated,
      ],
      CustomerHomeVisualKind.dessert =>
      const [
        PopqPalette.coral,
        PopqPalette.purple,
      ],
      CustomerHomeVisualKind
          .koreanFood =>
      const [
        PopqPalette.forest,
        PopqPalette.nightElevated,
      ],
      CustomerHomeVisualKind.steak =>
      const [
        Color(0xFF5F3B2F),
        PopqPalette.nightElevated,
      ],
      CustomerHomeVisualKind
          .membership =>
      const [
        PopqPalette.purple,
        PopqPalette.nightElevated,
      ],
      CustomerHomeVisualKind
          .popupMarket =>
      const [
        PopqPalette.purple,
        Color(0xFF3A2159),
      ],
      CustomerHomeVisualKind.cafe =>
      const [
        Color(0xFF5F3B2F),
        PopqPalette.nightElevated,
      ],
    };
  }

  return switch (kind) {
    CustomerHomeVisualKind.taco =>
    const [
      PopqPalette.coral,
      Color(0xFFFFB15C),
    ],
    CustomerHomeVisualKind.dessert =>
    const [
      Color(0xFFFF8DA1),
      PopqPalette.coral,
    ],
    CustomerHomeVisualKind
        .koreanFood =>
    const [
      PopqPalette.forest,
      Color(0xFF4F8D73),
    ],
    CustomerHomeVisualKind.steak =>
    const [
      Color(0xFF7A4D3A),
      Color(0xFFC67C58),
    ],
    CustomerHomeVisualKind
        .membership =>
    const [
      PopqPalette.purple,
      PopqPalette.coral,
    ],
    CustomerHomeVisualKind
        .popupMarket =>
    const [
      PopqPalette.purple,
      Color(0xFFB794F6),
    ],
    CustomerHomeVisualKind.cafe =>
    const [
      Color(0xFF7A4D3A),
      Color(0xFFC67C58),
    ],
  };
}
