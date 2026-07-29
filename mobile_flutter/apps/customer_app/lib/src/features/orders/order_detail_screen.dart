import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import 'customer_order_repository.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    required this.orderPublicId,
    required this.repository,
    super.key,
  });

  final String orderPublicId;
  final CustomerOrderRepository repository;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  CustomerOrder? _order;
  Object? _error;
  var _loading = true;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문 상세')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(message: '최신 주문 상태를 확인하고 있어요.');
    }
    if (_error != null || _order == null) {
      return PopqErrorView(message: '주문 상세를 불러오지 못했습니다.', onRetry: _load);
    }
    final order = _order!;
    return RefreshIndicator(
      onRefresh: _sync,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            decoration: BoxDecoration(
              color: PopqPalette.forest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: PopqPalette.lime,
                  size: 48,
                ),
                const SizedBox(height: PopqSpacing.sm),
                Text(
                  _statusLabel(order.status),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  order.storeName,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          for (final item in order.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.productName),
              subtitle: Text('${item.quantity}개'),
              trailing: Text(_won(item.itemTotalPrice)),
            ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('총 결제 금액'),
            trailing: Text(
              _won(order.totalAmount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          if (order.status == 'COMPLETED') ...[
            FilledButton.icon(
              onPressed: () async {
                final created = await context.push<bool>(
                  '${CustomerRoutes.orders}/${order.orderPublicId}/review',
                );
                if (!mounted) return;
                if (created == true) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('리뷰를 등록했어요.')));
                }
              },
              icon: const Icon(Icons.rate_review_rounded),
              label: const Text('리뷰 작성'),
            ),
            const SizedBox(height: PopqSpacing.sm),
          ],
          OutlinedButton.icon(
            onPressed: _syncing ? null : _sync,
            icon: const Icon(Icons.sync_rounded),
            label: Text(_syncing ? '확인 중...' : '최신 상태 확인'),
          ),
          const SizedBox(height: PopqSpacing.sm),
          Text(
            '서버 버전 ${order.version} · 알림 수신 후에도 이 API로 최신 상태를 다시 확인합니다.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.repository.findOne(widget.orderPublicId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = caught;
        _loading = false;
      });
    }
  }

  Future<void> _sync() async {
    final current = _order;
    if (current == null) return;
    setState(() => _syncing = true);
    try {
      final result = await widget.repository.sync(
        current.orderPublicId,
        current.version,
      );
      if (!mounted) return;
      setState(() {
        if (result.order != null) _order = result.order;
        _syncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.refreshRequired ? '최신 주문 상태로 갱신했습니다.' : '이미 최신 상태입니다.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _syncing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('최신 상태를 확인하지 못했습니다.')));
    }
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'CREATED' => '결제 대기',
    'PLACED' => '주문 접수 대기',
    'ACCEPTED' => '주문이 접수됐어요',
    'PREPARING' => '상품을 준비하고 있어요',
    'READY' => '준비가 완료됐어요',
    'COMPLETED' => '주문 완료',
    'REJECTED' => '주문 거절',
    'CANCELED' => '주문 취소',
    'EXPIRED' => '결제 만료',
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
