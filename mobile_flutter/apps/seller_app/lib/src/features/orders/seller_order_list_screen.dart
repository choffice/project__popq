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
                      labelText: '二쇰Ц???뺤씤???ъ뾽??,
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
                              ? '?ъ뾽?μ쓣 ?좏깮??二쇱꽭??'
                              : '?ъ뾽?μ쓣 遺덈윭?ㅻ뒗 以?..',
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
                Tab(text: '吏꾪뻾 以?),
                Tab(text: '吏??二쇰Ц'),
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
          return const PopqLoadingView(message: '?ㅽ넗??二쇰Ц??遺덈윭?ㅺ퀬 ?덉뼱??');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '?좏깮???ㅽ넗?댁쓽 二쇰Ц??遺덈윭?ㅼ? 紐삵뻽?듬땲??',
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
                        ? '吏꾪뻾 以묒씤 二쇰Ц???놁뼱??'
                        : '${_dateLabel(_pastDate)} 吏??二쇰Ц???놁뼱??',
                    description: '?꾨옒濡??밴꺼 二쇰Ц 紐⑸줉???덈줈怨좎묠?????덉뼱??',
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
      throw StateError('?ㅻⅨ ?ъ뾽?μ쓽 二쇰Ц ?묐떟???ы븿?섏뼱 ?덉뒿?덈떎.');
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
      null => '?꾩껜',
      'ACCEPTED_PREPARING' => '?묒닔쨌以鍮?以?,
      'COMPLETED' => '泥섎━?꾨즺',
      'CANCELED_FAMILY' => '二쇰Ц痍⑥냼',
      'REJECTED_FAMILY' => '二쇰Ц嫄곗젅',
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
              accepting ? '?좉퇋 二쇰Ц ?묒닔 以? : '?좉퇋 二쇰Ц ?묒닔 以묒?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accepting ? Colors.black : statusColor,
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
          title: const Text('二쇰Ц ?묒닔瑜??좎떆 以묒??좉퉴??'),
          content: const Text(
            '?대? ?묒닔??二쇰Ц? 怨꾩냽 泥섎━?????덇퀬, '
            '?덈줈??二쇰Ц留?諛쏆? ?딄쾶 ?⑸땲??',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('痍⑥냼'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('?묒닔 以묒?'),
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
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          SnackBar(
            content: Text(
              nextValue
                  ? '?덈줈??二쇰Ц ?묒닔瑜??ㅼ떆 ?쒖옉?덉뒿?덈떎.'
                  : '?덈줈??二쇰Ц ?묒닔瑜??좎떆 以묒??덉뒿?덈떎.',
            ),
          ),
        );
    } on PopqFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      debugPrint('?먮ℓ??二쇰Ц ?묒닔 ?곹깭 蹂寃??ㅻ쪟: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentTopSnackBar()
        ..showTopSnackBar(
          const SnackBar(
            content: Text('二쇰Ц ?묒닔 ?곹깭瑜?蹂寃쏀븯吏 紐삵뻽?듬땲?? ?ㅼ떆 ?쒕룄??二쇱꽭??'),
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
      debugPrint('?먮ℓ??二쇰Ц ?꾪솴 ?붿빟 ?숆린???ㅻ쪟: $error');
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
            '?묒닔?湲?$waiting',
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
      helpText: '吏??二쇰Ц ?좎쭨 ?좏깮',
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
        debugPrint('?먮ℓ??二쇰Ц 紐⑸줉 ?ㅼ떆媛?援щ룆 ?ㅻ쪟: $error');
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

    // ?좉퇋 二쇰Ц?닿굅???곹깭媛 ??寃쎄퀎瑜??섎뒗 寃쎌슦源뚯? ?뺥솗??諛섏쁺?섍린 ?꾪빐
    // ?대깽???곸슜 吏곹썑 REST ?ㅻ깄?룹쑝濡???踰?蹂댁젙?쒕떎.
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
      debugPrint('?먮ℓ??二쇰Ц 紐⑸줉 REST ?숆린???ㅻ쪟: $error');
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
      order.items.map((item) => '${item.productName} ${item.quantity}媛?),
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
                '${sellerOrderTypeLabel(order.orderType)} 쨌 珥?${order.totalQuantity}媛?,
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
    'CREATED' => '寃곗젣 ?湲?,
    'PLACED' => '?묒닔 ?湲?,
    'ACCEPTED' => '?묒닔 ?꾨즺',
    'PREPARING' => '以鍮?以?,
    'READY' => '以鍮??꾨즺',
    'COMPLETED' => '二쇰Ц ?꾨즺',
    'REJECTED' => '二쇰Ц 嫄곗젅',
    'CANCELED' => '二쇰Ц 痍⑥냼',
    'EXPIRED' => '寃곗젣 留뚮즺',
    _ => status,
  };
}

String sellerOrderTypeLabel(String orderType) {
  return switch (orderType) {
    'TAKEOUT' => '?ъ옣',
    'DINE_IN' => '留ㅼ옣',
    'DELIVERY' => '諛곕떖',
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
  return '$buffer??;
}

