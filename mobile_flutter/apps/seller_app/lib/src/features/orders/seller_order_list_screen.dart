import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/seller_realtime_scope.dart';
import '../../routing/seller_router.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_order_repository.dart';

class SellerOrderListScreen extends StatefulWidget {
  const SellerOrderListScreen({
    required this.repository,
    required this.storeRepository,
    required this.selectionController,
    this.initialCurrentFilter,
    super.key,
  });

  final SellerOrderRepository repository;
  final SellerStoreRepository storeRepository;
  final SellerStoreSelectionController selectionController;
  final String? initialCurrentFilter;

  @override
  State<SellerOrderListScreen> createState() => _SellerOrderListScreenState();
}

class _SellerOrderListScreenState extends State<SellerOrderListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _pollingInterval = Duration(seconds: 3);
  static const _currentStatuses = <String>[
    'PLACED',
    'ACCEPTED',
    'PREPARING',
    'READY',
  ];
  static const _recentStatuses = <String>[
    'COMPLETED',
    'CANCELED',
    'REJECTED',
    'EXPIRED',
  ];

  late final TabController _tabController;
  late Future<List<SellerStore>> _stores;
  late Future<List<SellerOrder>> _orders;
  String? _currentFilter;
  String? _recentFilter;
  late DateTime _pastDate;
  Map<int, SellerDashboardSummary> _summariesByStoreId = const {};
  List<SellerStore> _storeSnapshot = const <SellerStore>[];
  var _updatingOrderAccepting = false;
  var _requestSerial = 0;
  var _loadedTabIndex = 0;
  var _lastConnectionEpoch = 0;
  var _isAppActive = true;

  List<SellerOrder> _orderSnapshot = const <SellerOrder>[];
  Timer? _pollingTimer;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _storeOrderSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _currentFilter = widget.initialCurrentFilter;
    final seoulNow = DateTime.now().toUtc().add(const Duration(hours: 9));
    _pastDate = DateTime(seoulNow.year, seoulNow.month, seoulNow.day);
    widget.selectionController.addListener(_handleSelectionChanged);
    _stores = _loadStores();
    _orders = _loadOrders();
    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextRealtimeClient = SellerRealtimeScope.maybeOf(context);
    if (identical(_realtimeClient, nextRealtimeClient)) {
      return;
    }

    _realtimeClient?.removeListener(_handleRealtimeClientChanged);
    _storeOrderSubscription?.cancel();
    _storeOrderSubscription = null;

    _realtimeClient = nextRealtimeClient;
    _lastConnectionEpoch = nextRealtimeClient?.connectionEpoch ?? 0;
    nextRealtimeClient?.addListener(_handleRealtimeClientChanged);

    _subscribeToSelectedStore();
    _updatePollingForConnection();
  }

  @override
  void didUpdateWidget(covariant SellerOrderListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCurrentFilter != widget.initialCurrentFilter) {
      _currentFilter = widget.initialCurrentFilter;
    }
    if (oldWidget.selectionController != widget.selectionController) {
      oldWidget.selectionController.removeListener(_handleSelectionChanged);
      widget.selectionController.addListener(_handleSelectionChanged);
      _subscribeToSelectedStore();
      setState(() {
        _orderSnapshot = const <SellerOrder>[];
        _stores = _loadStores();
        _orders = _loadOrders();
      });
      _updatePollingForConnection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _subscribeToSelectedStore();
        _updatePollingForConnection();
        unawaited(_refreshOrdersSilently());
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isAppActive = false;
        _stopPolling();
        return;
    }
  }

  @override
  void dispose() {
    _requestSerial++;
    _stopPolling();
    _storeOrderSubscription?.cancel();
    _storeOrderSubscription = null;
    _realtimeClient?.removeListener(_handleRealtimeClientChanged);
    WidgetsBinding.instance.removeObserver(this);
    widget.selectionController.removeListener(_handleSelectionChanged);
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<List<SellerStore>>(
          future: _stores,
          builder: (context, snapshot) {
            final stores = snapshot.data ?? const <SellerStore>[];
            final selectedId = widget.selectionController.selectedStoreId;
            final validValue =
                stores.any((store) => store.storeId == selectedId)
                ? selectedId
                : null;
            SellerStore? selectedStore;
            if (validValue != null) {
              for (final store in stores) {
                if (store.storeId == validValue) {
                  selectedStore = store;
                  break;
                }
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PopqSpacing.md,
                    PopqSpacing.md,
                    PopqSpacing.md,
                    PopqSpacing.xs,
                  ),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '주문을 확인할 사업장',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        key: const Key('seller-order-store-selector'),
                        value: validValue,
                        isExpanded: true,
                        isDense: true,
                        hint: Text(
                          snapshot.connectionState == ConnectionState.done
                              ? '사업장을 선택해 주세요.'
                              : '사업장을 불러오는 중...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: stores
                            .map(
                              (store) => DropdownMenuItem<int>(
                                value: store.storeId,
                                child: _storeDropdownItem(store),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) => stores
                            .map((store) => _storeDropdownItem(store))
                            .toList(),
                        onChanged:
                            snapshot.connectionState == ConnectionState.done
                            ? (storeId) {
                                if (storeId != null) {
                                  widget.selectionController.select(storeId);
                                }
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
                if (selectedStore != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PopqSpacing.md,
                      PopqSpacing.xs,
                      PopqSpacing.md,
                      PopqSpacing.sm,
                    ),
                    child: _buildOrderOperationCard(selectedStore),
                  ),
              ],
            );
          },
        ),
        Builder(
          builder: (context) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final activeColor = dark
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFF35663A);
            return TabBar(
              controller: _tabController,
              labelColor: activeColor,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: activeColor,
              dividerColor: Theme.of(context).colorScheme.outlineVariant,
              tabs: const [
                Tab(text: '진행 중'),
                Tab(text: '지난 주문'),
              ],
            );
          },
        ),
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) => _tabController.index == 1
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PopqSpacing.md,
                    PopqSpacing.sm,
                    PopqSpacing.md,
                    0,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: _selectPastDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(_dateLabel(_pastDate)),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(
          height: 56,
          child: AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              final current = _tabController.index == 0;
              final filters = current
                  ? const <String?>[
                      null,
                      'PLACED',
                      'ACCEPTED_PREPARING',
                      'READY',
                    ]
                  : const <String?>[
                      null,
                      'COMPLETED',
                      'CANCELED_FAMILY',
                      'REJECTED_FAMILY',
                    ];
              final selected = current ? _currentFilter : _recentFilter;

              return FutureBuilder<List<SellerOrder>>(
                future: _orders,
                builder: (context, orderSnapshot) {
                  final source = orderSnapshot.data ?? _orderSnapshot;
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: PopqSpacing.md,
                      vertical: PopqSpacing.sm,
                    ),
                    itemCount: filters.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: PopqSpacing.xs),
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      final count = current
                          ? _currentOrderCountForFilter(source, filter)
                          : null;
                      return FilterChip(
                        label: Text(
                          count == null
                              ? _filterLabel(filter)
                              : '${_filterLabel(filter)} $count',
                        ),
                        selected: selected == filter,
                        selectedColor: const Color(0xFFFFC9BA),
                        checkmarkColor: const Color(0xFF4A1C12),
                        labelStyle: TextStyle(
                          color: selected == filter
                              ? const Color(0xFF4A1C12)
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: selected == filter
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                        onSelected: (_) => _selectFilter(filter),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        Expanded(child: _buildOrders()),
      ],
    );
  }

  Widget _buildOrders() {
    return FutureBuilder<List<SellerOrder>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PopqLoadingView(message: '스토어 주문을 불러오고 있어요.');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '선택한 스토어의 주문을 불러오지 못했습니다.',
            onRetry: _reload,
          );
        }
        final orders = _visibleOrders(snapshot.requireData);
        if (orders.isEmpty) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: PopqEmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: _tabController.index == 0
                        ? '진행 중인 주문이 없어요.'
                        : '${_dateLabel(_pastDate)} 지난 주문이 없어요.',
                    description: '아래로 당겨 주문 목록을 새로고침할 수 있어요.',
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.sm,
              PopqSpacing.md,
              PopqSpacing.xl,
            ),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: PopqSpacing.sm),
            itemBuilder: (context, index) => _OrderCard(
              order: orders[index],
              onTap: () => _openOrder(orders[index]),
            ),
          ),
        );
      },
    );
  }

  Future<List<SellerStore>> _loadStores() async {
    final results = await Future.wait([
      widget.storeRepository.findAll(),
      widget.storeRepository.findDashboardSummaries(),
    ]);
    final stores = (results[0] as List<SellerStore>)
        .where((store) => store.status == 'ACTIVE')
        .toList();
    _storeSnapshot = List<SellerStore>.unmodifiable(stores);
    final summaries = results[1] as List<SellerDashboardSummary>;
    _summariesByStoreId = {
      for (final summary in summaries) summary.storeId: summary,
    };
    final selectedId = widget.selectionController.selectedStoreId;
    if (stores.isNotEmpty &&
        !stores.any((store) => store.storeId == selectedId)) {
      await widget.selectionController.select(stores.first.storeId);
    }
    return stores;
  }

  Future<List<SellerOrder>> _loadOrders() async {
    final storeId = widget.selectionController.selectedStoreId;
    if (storeId == null) return const [];
    final serial = ++_requestSerial;
    final current = _tabController.index == 0;
    final orders = await widget.repository.findAll(
      storeId,
      statuses: current ? _currentStatuses : _recentStatuses,
      date: current ? null : _pastDate,
    );
    if (serial != _requestSerial ||
        storeId != widget.selectionController.selectedStoreId) {
      return const [];
    }
    if (orders.any((order) => order.storeId != storeId)) {
      throw StateError('다른 사업장의 주문 응답이 포함되어 있습니다.');
    }
    _orderSnapshot = List<SellerOrder>.unmodifiable(orders);
    return orders;
  }

  List<SellerOrder> _visibleOrders(List<SellerOrder> source) {
    final current = _tabController.index == 0;
    final baseStatuses = current ? _currentStatuses : _recentStatuses;
    final filter = current ? _currentFilter : _recentFilter;
    final filtered = source.where((order) {
      if (!baseStatuses.contains(order.status)) return false;
      return switch (filter) {
        null => true,
        'ACCEPTED_PREPARING' =>
          order.status == 'ACCEPTED' || order.status == 'PREPARING',
        'CANCELED_FAMILY' =>
          order.status == 'CANCELED' || order.status == 'EXPIRED',
        'REJECTED_FAMILY' => order.status == 'REJECTED',
        _ => order.status == filter,
      };
    }).toList();
    filtered.sort((left, right) {
      final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return filtered;
  }

  Future<void> _openOrder(SellerOrder order) async {
    await context.push(
      '${SellerRoutes.orders}/${order.orderPublicId}?storeId=${order.storeId}',
    );
    if (mounted &&
        widget.selectionController.selectedStoreId == order.storeId) {
      await _reload();
    }
  }

  void _handleSelectionChanged() {
    if (!mounted) return;
    _requestSerial++;
    _orderSnapshot = const <SellerOrder>[];
    _subscribeToSelectedStore();
    setState(() => _orders = _loadOrders());
    _updatePollingForConnection();
  }

  void _handleTabChanged() {
    if (!mounted || _loadedTabIndex == _tabController.index) return;
    _loadedTabIndex = _tabController.index;
    _orderSnapshot = const <SellerOrder>[];
    setState(() => _orders = _loadOrders());
  }

  void _selectFilter(String? filter) {
    setState(() {
      if (_tabController.index == 0) {
        _currentFilter = filter;
      } else {
        _recentFilter = filter;
      }
    });
  }

  String _filterLabel(String? filter) {
    return switch (filter) {
      null => '전체',
      'ACCEPTED_PREPARING' => '접수·준비 중',
      'COMPLETED' => '처리완료',
      'CANCELED_FAMILY' => '주문취소',
      'REJECTED_FAMILY' => '주문거절',
      _ => sellerOrderStatusLabel(filter),
    };
  }

  int _currentOrderCountForFilter(
    List<SellerOrder> orders,
    String? filter,
  ) {
    return orders.where((order) {
      if (!_currentStatuses.contains(order.status)) return false;
      return switch (filter) {
        null => true,
        'PLACED' => order.status == 'PLACED',
        'ACCEPTED_PREPARING' =>
          order.status == 'ACCEPTED' || order.status == 'PREPARING',
        'READY' => order.status == 'READY',
        _ => false,
      };
    }).length;
  }

  Future<void> _reload() async {
    setState(() {
      _stores = _loadStores();
      _orders = _loadOrders();
    });
    await Future.wait([_stores, _orders]);
  }

  Widget _buildOrderOperationCard(SellerStore store) {
    final accepting = store.orderAcceptingEnabled;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = accepting ? colorScheme.primary : colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PopqSpacing.sm,
        vertical: PopqSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            accepting
                ? Icons.check_circle_rounded
                : Icons.pause_circle_filled_rounded,
            size: 18,
            color: statusColor,
          ),
          const SizedBox(width: PopqSpacing.xs),
          Expanded(
            child: Text(
              accepting ? '신규 주문 접수 중' : '신규 주문 접수 중지',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: PopqSpacing.xs),
          if (_updatingOrderAccepting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch.adaptive(
              value: accepting,
              onChanged: store.canManage
                  ? (value) => _changeOrderAccepting(store, value)
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _changeOrderAccepting(
    SellerStore store,
    bool nextValue,
  ) async {
    if (_updatingOrderAccepting || !store.canManage) return;

    if (!nextValue) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('주문 접수를 잠시 중지할까요?'),
          content: const Text(
            '이미 접수된 주문은 계속 처리할 수 있고, '
            '새로운 주문만 받지 않게 됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('접수 중지'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _updatingOrderAccepting = true);

    try {
      final updated = await widget.storeRepository.update(
        store.storeId,
        storeType: store.storeType,
        name: store.name,
        description: store.description,
        address: store.address,
        detailAddress: store.detailAddress,
        representativeCategory: store.representativeCategory,
        imageUrl: store.imageUrl,
        phone: store.phone,
        latitude: store.latitude,
        longitude: store.longitude,
        openTime: store.openTime,
        closeTime: store.closeTime,
        operationStartDate: store.operationStartDate,
        operationEndDate: store.operationEndDate,
        closedDays: store.closedDays,
        takeoutAvailable: store.takeoutAvailable,
        dineInAvailable: store.dineInAvailable,
        orderAcceptingEnabled: nextValue,
        tags: store.tags,
      );

      final nextStores = _storeSnapshot
          .map((item) => item.storeId == updated.storeId ? updated : item)
          .toList(growable: false);
      _storeSnapshot = List<SellerStore>.unmodifiable(nextStores);

      if (!mounted) return;
      setState(() {
        _stores = Future<List<SellerStore>>.value(_storeSnapshot);
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              nextValue
                  ? '새로운 주문 접수를 다시 시작했습니다.'
                  : '새로운 주문 접수를 잠시 중지했습니다.',
            ),
          ),
        );
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      debugPrint('판매자 주문 접수 상태 변경 오류: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('주문 접수 상태를 변경하지 못했습니다. 다시 시도해 주세요.'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _updatingOrderAccepting = false);
      }
    }
  }

  Future<void> _refreshDashboardSummariesSilently() async {
    if (!mounted || !_isAppActive) return;

    try {
      final summaries = await widget.storeRepository.findDashboardSummaries();
      if (!mounted) return;
      setState(() {
        _summariesByStoreId = {
          for (final summary in summaries) summary.storeId: summary,
        };
      });
    } catch (error) {
      debugPrint('판매자 주문 현황 요약 동기화 오류: $error');
    }
  }

  Widget _storeDropdownItem(SellerStore store) {
    final waiting = _summariesByStoreId[store.storeId]?.waitingOrderCount ?? 0;
    return Row(
      children: [
        Expanded(
          child: Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (waiting > 0) ...[
          const SizedBox(width: PopqSpacing.xs),
          Icon(
            Icons.notifications_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 2),
          Text(
            '접수대기 $waiting',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _selectPastDate() async {
    final todayInSeoul = DateTime.now().toUtc().add(const Duration(hours: 9));
    final selected = await showDatePicker(
      context: context,
      initialDate: _pastDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        todayInSeoul.year,
        todayInSeoul.month,
        todayInSeoul.day,
      ),
      helpText: '지난 주문 날짜 선택',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _pastDate = DateTime(selected.year, selected.month, selected.day);
      _orderSnapshot = const <SellerOrder>[];
      _orders = _loadOrders();
    });
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) return;

    final client = _realtimeClient;
    if (client == null) {
      _updatePollingForConnection();
      return;
    }

    final connectionEpoch = client.connectionEpoch;
    if (client.isConnected && connectionEpoch != _lastConnectionEpoch) {
      _lastConnectionEpoch = connectionEpoch;
      unawaited(_refreshOrdersSilently());
    }

    _updatePollingForConnection();
  }

  void _subscribeToSelectedStore() {
    _storeOrderSubscription?.cancel();
    _storeOrderSubscription = null;

    final client = _realtimeClient;
    final storeId = widget.selectionController.selectedStoreId;
    if (client == null || storeId == null) return;

    _storeOrderSubscription = client.subscribeToStoreOrders(
      storeId: storeId,
      onEvent: _handleStoreOrderEvent,
      onError: (error) {
        debugPrint('판매자 주문 목록 실시간 구독 오류: $error');
      },
    );
  }

  void _handleStoreOrderEvent(PopqOrderRealtimeEvent event) {
    if (!mounted) return;

    final selectedStoreId = widget.selectionController.selectedStoreId;
    if (selectedStoreId == null || event.storeId != selectedStoreId) {
      return;
    }

    final index = _orderSnapshot.indexWhere(
      (order) => order.orderPublicId == event.orderPublicId,
    );

    if (index >= 0) {
      final current = _orderSnapshot[index];
      if (event.isDuplicateOrOlderThan(current.version)) {
        return;
      }

      final patched = List<SellerOrder>.of(_orderSnapshot);
      patched[index] = current.copyWith(
        status: event.currentStatus,
        version: event.version,
      );
      _orderSnapshot = List<SellerOrder>.unmodifiable(patched);

      setState(() {
        _orders = Future<List<SellerOrder>>.value(_orderSnapshot);
      });
    }

    // 신규 주문이거나 상태가 탭 경계를 넘는 경우까지 정확히 반영하기 위해
    // 이벤트 적용 직후 REST 스냅샷으로 한 번 보정한다.
    unawaited(_refreshOrdersSilently());
  }

  Future<void> _refreshOrdersSilently() async {
    if (!mounted || !_isAppActive) return;

    try {
      final loaded = await _loadOrders();
      if (!mounted) return;

      setState(() {
        _orders = Future<List<SellerOrder>>.value(
          List<SellerOrder>.unmodifiable(loaded),
        );
      });
      unawaited(_refreshDashboardSummariesSilently());
    } catch (error) {
      debugPrint('판매자 주문 목록 REST 동기화 오류: $error');
    }
  }

  void _updatePollingForConnection() {
    final shouldUseRestFallback =
        _realtimeClient?.shouldUseRestFallback ?? true;

    if (_isAppActive && shouldUseRestFallback) {
      _startPolling();
      return;
    }

    _stopPolling();
  }

  void _startPolling() {
    if (!_isAppActive ||
        !(_realtimeClient?.shouldUseRestFallback ?? true) ||
        (_pollingTimer?.isActive ?? false)) {
      return;
    }

    _pollingTimer = Timer.periodic(
      _pollingInterval,
      (_) => unawaited(_refreshOrdersSilently()),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  String _dateLabel(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.'
      '${date.day.toString().padLeft(2, '0')}';
}


class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final SellerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemSummary = formatPopqOrderItemSummary(
      order.items.map((item) => '${item.productName} ${item.quantity}개'),
    );
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(PopqSpacing.md),
        leading: CircleAvatar(
          backgroundColor: sellerOrderStatusColor(order.status),
          child: Icon(
            Icons.receipt_long_rounded,
            color: sellerOrderStatusForegroundColor(order.status),
          ),
        ),
        title: Text(
          sellerOrderStatusLabel(order.status),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: PopqSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatPopqOrderNumber(order.orderPublicId)),
              const SizedBox(height: 2),
              Text(
                itemSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${sellerOrderTypeLabel(order.orderType)} · 총 ${order.totalQuantity}개',
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: Text(
          sellerWon(order.totalAmount),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onTap: onTap,
      ),
    );
  }
}

String sellerOrderStatusLabel(String status) {
  return switch (status) {
    'CREATED' => '결제 대기',
    'PLACED' => '접수 대기',
    'ACCEPTED' => '접수 완료',
    'PREPARING' => '준비 중',
    'READY' => '준비 완료',
    'COMPLETED' => '주문 완료',
    'REJECTED' => '주문 거절',
    'CANCELED' => '주문 취소',
    'EXPIRED' => '결제 만료',
    _ => status,
  };
}

String sellerOrderTypeLabel(String orderType) {
  return switch (orderType) {
    'TAKEOUT' => '포장',
    'DINE_IN' => '매장',
    'DELIVERY' => '배달',
    _ => orderType,
  };
}

Color sellerOrderStatusColor(String status) {
  return switch (status) {
    'PLACED' => const Color(0xFFFFC9BA),
    'ACCEPTED' || 'PREPARING' => const Color(0xFFFFD98A),
    'READY' => const Color(0xFFC7D98B),
    'COMPLETED' => const Color(0xFFD7F0E3),
    'REJECTED' || 'CANCELED' || 'EXPIRED' => const Color(0xFFE7E4EA),
    _ => const Color(0xFFD9D2FF),
  };
}

Color sellerOrderStatusForegroundColor(String status) {
  return switch (status) {
    'PLACED' => const Color(0xFF4A1C12),
    'ACCEPTED' || 'PREPARING' => const Color(0xFF3F2B00),
    'READY' => const Color(0xFF263400),
    'COMPLETED' => const Color(0xFF123425),
    _ => const Color(0xFF29242E),
  };
}

String sellerWon(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '$buffer원';
}
