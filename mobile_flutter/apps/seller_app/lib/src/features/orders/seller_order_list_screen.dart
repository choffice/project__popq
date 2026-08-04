import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_order_repository.dart';

class SellerOrderListScreen extends StatefulWidget {
  const SellerOrderListScreen({
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final SellerOrderRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerOrderListScreen> createState() => _SellerOrderListScreenState();
}

class _SellerOrderListScreenState extends State<SellerOrderListScreen> {
  static const _filters = <String?>[
    null,
    'PLACED',
    'ACCEPTED',
    'PREPARING',
    'READY',
    'COMPLETED',
    'REJECTED',
    'CANCELED',
  ];

  String? _status;
  late Future<List<SellerOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: PopqSpacing.md,
              vertical: PopqSpacing.sm,
            ),
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: PopqSpacing.xs),
            itemBuilder: (context, index) {
              final status = _filters[index];
              return FilterChip(
                label: Text(
                  status == null ? '전체' : sellerOrderStatusLabel(status),
                ),
                selected: _status == status,
                onSelected: (_) => _selectStatus(status),
              );
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<SellerOrder>>(
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
              if (snapshot.requireData.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.55,
                        child: PopqEmptyView(
                          icon: Icons.receipt_long_outlined,
                          title: _status == null
                              ? '아직 주문이 없어요.'
                              : '${sellerOrderStatusLabel(_status!)} 주문이 없어요.',
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
                  itemCount: snapshot.requireData.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: PopqSpacing.sm),
                  itemBuilder: (context, index) {
                    final order = snapshot.requireData[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(PopqSpacing.md),
                        leading: CircleAvatar(
                          backgroundColor: sellerOrderStatusColor(order.status),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: PopqPalette.ink,
                          ),
                        ),
                        title: Text(
                          sellerOrderStatusLabel(order.status),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${formatPopqOrderNumber(order.orderPublicId)}\n'
                          '${sellerOrderTypeLabel(order.orderType)} · '
                          '${order.totalQuantity}개',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          sellerWon(order.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        onTap: () async {
                          await context.push(
                            '${SellerRoutes.orders}/${order.orderPublicId}',
                          );
                          if (mounted) await _reload();
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<SellerOrder>> _load() {
    final storeId = widget.selectionController.selectedStoreId;
    if (storeId == null) throw StateError('selected store is missing');
    return widget.repository.findAll(storeId, status: _status);
  }

  void _selectStatus(String? status) {
    setState(() {
      _status = status;
      _orders = _load();
    });
  }

  Future<void> _reload() async {
    setState(() => _orders = _load());
    await _orders;
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
