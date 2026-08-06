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
    super.key,
  });

  final SellerOrderRepository repository;
  final SellerStoreRepository storeRepository;
  final SellerStoreSelectionController selectionController;

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
  var _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    widget.selectionController.addListener(_handleSelectionChanged);
    _stores = _loadStores();
    _orders = _loadOrders();
  }

  @override
  void didUpdateWidget(covariant SellerOrderListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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
              child: DropdownButtonFormField<int>(
                key: const Key('seller-order-store-selector'),
                initialValue: validValue,
                decoration: const InputDecoration(
                  labelText: '주문을 확인할 사업장',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                items: stores
                    .map(
                      (store) => DropdownMenuItem<int>(
                        value: store.storeId,
                        child: Text(store.name),
                      ),
                    )
                    .toList(),
                onChanged: snapshot.connectionState == ConnectionState.done
                    ? (storeId) {
                        if (storeId != null) {
                          widget.selectionController.select(storeId);
                        }
                      }
                    : null,
              ),
            );
          },
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '진행 중'),
            Tab(text: '최근 주문'),
          ],
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
                        : '최근 주문이 없어요.',
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
    final stores = (await widget.storeRepository.findAll())
        .where((store) => store.status == 'ACTIVE')
        .toList();
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
    final orders = await widget.repository.findAll(storeId);
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
    if (!_tabController.indexIsChanging && mounted) setState(() {});
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
      'CANCELED_FAMILY' => '취소',
      'REJECTED_FAMILY' => '거절',
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
          child: const Icon(Icons.receipt_long_rounded, color: PopqPalette.ink),
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
    'PLACED' => const Color(0xFFFFD2C9),
    'ACCEPTED' || 'PREPARING' => const Color(0xFFFFE8A3),
    'READY' => PopqPalette.lime,
    'COMPLETED' => const Color(0xFFD7F0E3),
    'REJECTED' || 'CANCELED' || 'EXPIRED' => const Color(0xFFE7E4EA),
    _ => const Color(0xFFD9D2FF),
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
