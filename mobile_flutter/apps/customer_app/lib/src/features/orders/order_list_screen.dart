import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import 'customer_order_repository.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({required this.repository, super.key});

  final CustomerOrderRepository repository;

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late Future<List<CustomerOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = widget.repository.findAll();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerOrder>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PopqLoadingView(message: '주문 내역을 불러오고 있어요.');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(message: '주문 내역을 불러오지 못했습니다.', onRetry: _reload);
        }
        if (snapshot.requireData.isEmpty) {
          return const PopqEmptyView(
            icon: Icons.receipt_long_outlined,
            title: '아직 주문 내역이 없어요.',
            description: '마음에 드는 스토어에서 첫 주문을 시작해 보세요.',
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(PopqSpacing.md),
            itemCount: snapshot.requireData.length,
            separatorBuilder: (_, _) => const SizedBox(height: PopqSpacing.sm),
            itemBuilder: (context, index) {
              final order = snapshot.requireData[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(PopqSpacing.md),
                  leading: CircleAvatar(
                    backgroundColor: PopqPalette.lime,
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: PopqPalette.forest,
                    ),
                  ),
                  title: Text(order.storeName),
                  subtitle: Text(
                    '${_statusLabel(order.status)} · '
                    '${order.items.length}개 항목',
                  ),
                  trailing: Text(_won(order.totalAmount)),
                  onTap: () => context.push(
                    '${CustomerRoutes.orders}/${order.orderPublicId}',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _reload() async {
    setState(() {
      _orders = widget.repository.findAll();
    });
    await _orders;
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'CREATED' => '결제 대기',
    'PLACED' => '주문 접수 대기',
    'ACCEPTED' => '주문 접수',
    'PREPARING' => '준비 중',
    'READY' => '준비 완료',
    'COMPLETED' => '완료',
    'REJECTED' => '거절',
    'CANCELED' => '취소',
    'EXPIRED' => '만료',
    _ => status,
  };
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '$buffer원';
}
