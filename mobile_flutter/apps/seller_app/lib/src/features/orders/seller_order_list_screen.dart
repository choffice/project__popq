import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

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
    with SingleTickerProviderStateMixin {
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
  var _requestSerial = 0;
  var _loadedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _currentFilter = widget.initialCurrentFilter;
    final seoulNow = DateTime.now().toUtc().add(const Duration(hours: 9));
    _pastDate = DateTime(seoulNow.year, seoulNow.month, seoulNow.day);
    widget.selectionController.addListener(_handleSelectionChanged);
    _stores = _loadStores();
    _orders = _loadOrders();
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
      setState(() {
        _stores = _loadStores();
        _orders = _loadOrders();
      });
    }
  }

  @override
  void dispose() {
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
            final validValue = stores.any((store) => store.storeId == selectedId)
                ? selectedId
                : null;
            return Padding(
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
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
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
                  ? const <String?>[null, 'PLACED', 'ACCEPTED_PREPARING', 'READY']
                  : const <String?>[null, 'COMPLETED', 'CANCELED_FAMILY', 'REJECTED_FAMILY'];
              final selected = current ? _currentFilter : _recentFilter;
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
                  return FilterChip(
                    label: Text(_filterLabel(filter)),
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
    final summaries = results[1] as List<SellerDashboardSummary>;
    _summariesByStoreId = {
      for (final summary in summaries) summary.storeId: summary,
    };
    final selectedId = widget.selectionController.selectedStoreId;
    if (stores.isNotEmpty && !stores.any((store) => store.storeId == selectedId)) {
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
      final rightDate = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
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
    setState(() => _orders = _loadOrders());
  }

  void _handleTabChanged() {
    if (!mounted || _loadedTabIndex == _tabController.index) return;
    _loadedTabIndex = _tabController.index;
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

  Future<void> _reload() async {
    setState(() {
      _stores = _loadStores();
      _orders = _loadOrders();
    });
    await Future.wait([_stores, _orders]);
  }

  Widget _storeDropdownItem(SellerStore store) {
    final waiting = _summariesByStoreId[store.storeId]?.waitingOrderCount ?? 0;
    return Row(
      children: [
        Expanded(
          child: Text(
            store.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
      _orders = _loadOrders();
    });
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
              Text('${sellerOrderTypeLabel(order.orderType)} · 총 ${order.totalQuantity}개'),
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
