import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../home/seller_analytics_repository.dart';
import '../orders/seller_order_list_screen.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';

enum _SalesPeriod { day, month }

class SellerSalesScreen extends StatefulWidget {
  const SellerSalesScreen({
    required this.storeRepository,
    required this.analyticsRepository,
    required this.selectionController,
    super.key,
  });

  final SellerStoreRepository storeRepository;
  final SellerAnalyticsRepository analyticsRepository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerSalesScreen> createState() => _SellerSalesScreenState();
}

class _SellerSalesScreenState extends State<SellerSalesScreen> {
  _SalesPeriod _period = _SalesPeriod.day;

  _StoreSales? _storeSales;
  Object? _error;

  var _loading = true;
  int? _lastSelectedStoreId;

  @override
  void initState() {
    super.initState();

    _lastSelectedStoreId = widget.selectionController.selectedStoreId;

    widget.selectionController.addListener(_handleSelectionChanged);

    _load();
  }

  @override
  void didUpdateWidget(covariant SellerSalesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectionController == widget.selectionController) {
      return;
    }

    oldWidget.selectionController.removeListener(_handleSelectionChanged);
    widget.selectionController.addListener(_handleSelectionChanged);

    _lastSelectedStoreId = widget.selectionController.selectedStoreId;

    _load();
  }

  @override
  void dispose() {
    widget.selectionController.removeListener(_handleSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PopqLoadingView(
        message: '선택한 사업장 매출을 집계하고 있어요.',
      );
    }

    if (_error != null) {
      return PopqErrorView(
        message: '매출 성과를 불러오지 못했습니다.',
        onRetry: _load,
      );
    }

    final storeSales = _storeSales;

    if (storeSales == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(PopqSpacing.lg),
          children: const [
            SizedBox(height: 120),
            PopqEmptyView(
              icon: Icons.storefront_outlined,
              title: '선택된 사업장이 없어요.',
              description: '대시보드에서 사업장을 선택한 뒤 다시 확인해 주세요.',
            ),
          ],
        ),
      );
    }

    final store = storeSales.store;
    final summary = storeSales.summary;

    final menus = summary.topProducts.toList()
      ..sort((left, right) => right.sales.compareTo(left.sales));

    final dailySales = summary.dailySales.toList()
      ..sort((left, right) => right.date.compareTo(left.date));

    final todaySales = _findTodaySales(summary);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PopqSpacing.md),
        children: [
          SegmentedButton<_SalesPeriod>(
            segments: const [
              ButtonSegment(
                value: _SalesPeriod.day,
                label: Text('일 매출'),
              ),
              ButtonSegment(
                value: _SalesPeriod.month,
                label: Text('월 매출'),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (selection) {
              setState(() {
                _period = selection.single;
              });

              _load();
            },
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text(
            store.name,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: PopqSpacing.xs),
          Text(
            '${_storeTypeLabel(store.storeType)} · '
            '${_businessStatusLabel(store.businessStatus)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: PopqSpacing.sm),
          Card(
            color: colorScheme.inverseSurface,
            child: Padding(
              padding: const EdgeInsets.all(PopqSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _period == _SalesPeriod.day ? '오늘 순매출' : '이번 달 순매출',
                    style: TextStyle(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                  const SizedBox(height: PopqSpacing.xs),
                  Text(
                    sellerWon(summary.netSales),
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: PopqSpacing.sm),
                  Text(
                    '${_periodLabel(summary)} · 완료 주문 '
                    '${summary.completedOrderCount}건',
                    style: TextStyle(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.78,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text(
            '결제 정산',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: PopqSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SalesMetricCard(
                  icon: Icons.payments_outlined,
                  label: '결제 완료 금액',
                  value: sellerWon(summary.grossSales),
                ),
              ),
              const SizedBox(width: PopqSpacing.sm),
              Expanded(
                child: _SalesMetricCard(
                  icon: Icons.undo_rounded,
                  label: '환불 금액',
                  value: sellerWon(summary.refundedAmount),
                  description: summary.refundCount > 0
                      ? '${summary.refundCount}건 환불·취소'
                      : '환불·취소 없음',
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SalesMetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '순매출',
                  value: sellerWon(summary.netSales),
                ),
              ),
              const SizedBox(width: PopqSpacing.sm),
              Expanded(
                child: _SalesMetricCard(
                  icon: Icons.today_outlined,
                  label: '오늘 매출',
                  value: sellerWon(todaySales),
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PopqSpacing.xs),
            child: Text(
              '결제 완료 금액은 승인된 원결제 금액이며, 환불 금액은 성공한 부분환불·전액취소 금액을 포함합니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text(
            '기간별 매출',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: PopqSpacing.sm),
          if (dailySales.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(PopqSpacing.lg),
                child: Text('해당 기간에 집계된 매출이 없습니다.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < dailySales.length; index++) ...[
                    _DailySalesTile(item: dailySales[index]),
                    if (index != dailySales.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          const SizedBox(height: PopqSpacing.lg),
          Text(
            '주문 유형별 매출',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: PopqSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SalesMetricCard(
                  icon: Icons.table_restaurant_outlined,
                  label: '매장 식사',
                  value: sellerWon(summary.dineInSales),
                ),
              ),
              const SizedBox(width: PopqSpacing.sm),
              Expanded(
                child: _SalesMetricCard(
                  icon: Icons.shopping_bag_outlined,
                  label: '포장',
                  value: sellerWon(summary.takeoutSales),
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text(
            '메뉴별 매출',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: PopqSpacing.sm),
          if (menus.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(PopqSpacing.lg),
                child: Text('해당 기간에 집계된 메뉴 매출이 없습니다.'),
              ),
            )
          else
            for (final item in menus.take(10))
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu_rounded),
                  title: Text(item.name),
                  subtitle: Text('${item.quantity}개 판매'),
                  trailing: Text(sellerWon(item.sales)),
                ),
              ),
        ],
      ),
    );
  }

  void _handleSelectionChanged() {
    final selectedStoreId = widget.selectionController.selectedStoreId;

    if (_lastSelectedStoreId == selectedStoreId) {
      return;
    }

    _lastSelectedStoreId = selectedStoreId;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final selectedStoreId = widget.selectionController.selectedStoreId;

    if (selectedStoreId == null) {
      setState(() {
        _storeSales = null;
        _loading = false;
      });

      return;
    }

    try {
      final now = DateTime.now();

      final from = _period == _SalesPeriod.day
          ? DateTime(now.year, now.month, now.day)
          : DateTime(now.year, now.month);

      debugPrint('[SELLER SALES] store START');
      final store = await widget.storeRepository.findOne(selectedStoreId);
      debugPrint('[SELLER SALES] store SUCCESS');

      final summary = await widget.analyticsRepository.findSales(
        selectedStoreId,
        from: from,
        to: now,
      );
      debugPrint('[SELLER SALES] analytics SUCCESS');

      if (!mounted ||
          widget.selectionController.selectedStoreId != selectedStoreId) {
        return;
      }

      setState(() {
        _storeSales = _StoreSales(store, summary);
        _loading = false;
      });
    } catch (error) {
      debugPrint('[SELLER SALES] ERROR: $error');
      if (!mounted ||
          widget.selectionController.selectedStoreId != selectedStoreId) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  int _findTodaySales(SellerSalesSummary summary) {
    final now = DateTime.now();
    final today = _dateKey(now);

    for (final item in summary.dailySales) {
      if (item.date == today) {
        return item.sales;
      }
    }

    return 0;
  }

  String _periodLabel(SellerSalesSummary summary) {
    if (summary.from == summary.to) {
      return _displayDate(summary.from);
    }

    return '${_displayDate(summary.from)} ~ ${_displayDate(summary.to)}';
  }
}

class _SalesMetricCard extends StatelessWidget {
  const _SalesMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.description,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: PopqSpacing.sm),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: PopqSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: PopqSpacing.xs),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailySalesTile extends StatelessWidget {
  const _DailySalesTile({required this.item});

  final SellerDailySales item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: const Icon(Icons.calendar_today_outlined),
      title: Text(_displayDate(item.date)),
      subtitle: Text('결제 승인 ${item.orderCount}건'),
      trailing: Text(
        sellerWon(item.sales),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StoreSales {
  const _StoreSales(this.store, this.summary);

  final SellerStore store;
  final SellerSalesSummary summary;
}

String _storeTypeLabel(String storeType) {
  return storeType == 'EVENT_COMMERCE' ? '행사·팝업 판매점' : '일반 매장';
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '영업 중',
    'PRE_OPEN' => '준비중',
    _ => status,
  };
}

String _dateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _displayDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return '${parsed.month}월 ${parsed.day}일';
}
