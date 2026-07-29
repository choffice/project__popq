import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../orders/seller_order_list_screen.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_analytics_repository.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({
    required this.storeRepository,
    required this.analyticsRepository,
    required this.selectionController,
    super.key,
  });

  final SellerStoreRepository storeRepository;
  final SellerAnalyticsRepository analyticsRepository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  SellerStore? _store;
  SellerSalesSummary? _sales;
  Object? _error;
  var _loading = true;
  var _changingStatus = false;

  int get _storeId {
    final storeId = widget.selectionController.selectedStoreId;
    if (storeId == null) throw StateError('selected store is missing');
    return storeId;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PopqLoadingView(message: '오늘의 운영 현황을 불러오고 있어요.');
    }
    if (_error != null || _store == null || _sales == null) {
      return PopqErrorView(
        message: '선택한 스토어의 운영 현황을 불러오지 못했습니다.',
        onRetry: _load,
      );
    }
    final store = _store!;
    final sales = _sales!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          PopqSpacing.md,
          PopqSpacing.sm,
          PopqSpacing.md,
          PopqSpacing.xl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            decoration: BoxDecoration(
              color: PopqPalette.ink,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roleLabel(store.myRole).toUpperCase(),
                  style: const TextStyle(
                    color: PopqPalette.lime,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  store.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: PopqSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Colors.white70),
                    const SizedBox(width: PopqSpacing.sm),
                    Text(
                      _businessStatusLabel(store.businessStatus),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text('영업 상태', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PopqSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'PRE_OPEN', label: Text('영업 준비')),
              ButtonSegment(value: 'OPEN', label: Text('영업 중')),
              ButtonSegment(value: 'CLOSED', label: Text('영업 종료')),
            ],
            selected: {store.businessStatus},
            onSelectionChanged:
                _changingStatus ||
                    (store.myRole != 'OWNER' && store.myRole != 'MANAGER')
                ? null
                : (selection) => _changeStatus(selection.single),
          ),
          if (store.myRole == 'STAFF')
            const Padding(
              padding: EdgeInsets.only(top: PopqSpacing.xs),
              child: Text('영업 상태 변경은 OWNER 또는 MANAGER만 할 수 있습니다.'),
            ),
          if (_changingStatus) const LinearProgressIndicator(),
          const SizedBox(height: PopqSpacing.lg),
          Text('오늘의 매출', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: PopqSpacing.sm),
          Wrap(
            spacing: PopqSpacing.sm,
            runSpacing: PopqSpacing.sm,
            children: [
              _MetricCard(
                label: '순매출',
                value: sellerWon(sales.netSales),
                icon: Icons.payments_outlined,
              ),
              _MetricCard(
                label: '완료 주문',
                value: '${sales.completedOrderCount}건',
                icon: Icons.receipt_long_outlined,
              ),
              _MetricCard(
                label: '객단가',
                value: sellerWon(sales.averageOrderAmount),
                icon: Icons.calculate_outlined,
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PopqSpacing.md),
              child: Column(
                children: [
                  _SalesRow(label: '매장 주문', amount: sales.dineInSales),
                  const Divider(),
                  _SalesRow(label: '포장 주문', amount: sales.takeoutSales),
                ],
              ),
            ),
          ),
          if (sales.topProducts.isNotEmpty) ...[
            const SizedBox(height: PopqSpacing.lg),
            Text('오늘의 인기 상품', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: PopqSpacing.sm),
            Card(
              child: Column(
                children: [
                  for (final product in sales.topProducts.take(3))
                    ListTile(
                      leading: const Icon(Icons.emoji_events_outlined),
                      title: Text(product.name),
                      subtitle: Text('${product.quantity}개 판매'),
                      trailing: Text(sellerWon(product.sales)),
                    ),
                ],
              ),
            ),
          ],
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
      final stores = await widget.storeRepository.findAll();
      final store = stores.firstWhere((item) => item.storeId == _storeId);
      final now = DateTime.now();
      final sales = await widget.analyticsRepository.findSales(
        _storeId,
        from: now,
        to: now,
      );
      if (!mounted) return;
      setState(() {
        _store = store;
        _sales = sales;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(String status) async {
    if (_changingStatus || status == _store?.businessStatus) return;
    setState(() => _changingStatus = true);
    try {
      final updated = await widget.storeRepository.changeBusinessStatus(
        _storeId,
        status,
      );
      if (!mounted) return;
      setState(() {
        _store = updated;
        _changingStatus = false;
      });
      _showMessage('${_businessStatusLabel(status)} 상태로 변경했습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _changingStatus = false);
      _showMessage('영업 상태를 변경하지 못했습니다.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: PopqPalette.forest),
              const SizedBox(height: PopqSpacing.sm),
              Text(label),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesRow extends StatelessWidget {
  const _SalesRow({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(amount == 0 ? '0원' : sellerWon(amount))],
    );
  }
}

String _roleLabel(String role) {
  return switch (role) {
    'OWNER' => 'Owner',
    'MANAGER' => 'Manager',
    'STAFF' => 'Staff',
    _ => role,
  };
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '영업 중',
    'CLOSED' => '영업 종료',
    'PRE_OPEN' => '영업 준비',
    _ => status,
  };
}
