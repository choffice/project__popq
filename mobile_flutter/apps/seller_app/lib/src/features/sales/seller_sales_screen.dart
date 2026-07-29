import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../home/seller_analytics_repository.dart';
import '../orders/seller_order_list_screen.dart';
import '../stores/seller_store_repository.dart';

enum _SalesPeriod { day, month }

class SellerSalesScreen extends StatefulWidget {
  const SellerSalesScreen({
    required this.storeRepository,
    required this.analyticsRepository,
    super.key,
  });

  final SellerStoreRepository storeRepository;
  final SellerAnalyticsRepository analyticsRepository;

  @override
  State<SellerSalesScreen> createState() => _SellerSalesScreenState();
}

class _SellerSalesScreenState extends State<SellerSalesScreen> {
  _SalesPeriod _period = _SalesPeriod.day;
  List<_StoreSales>? _storeSales;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PopqLoadingView(message: '전체 사업장 매출을 집계하고 있어요.');
    }
    if (_error != null || _storeSales == null) {
      return PopqErrorView(message: '매출 성과를 불러오지 못했습니다.', onRetry: _load);
    }
    final sales = _storeSales!;
    final netSales = sales.fold(0, (sum, item) => sum + item.summary.netSales);
    final orders = sales.fold(
      0,
      (sum, item) => sum + item.summary.completedOrderCount,
    );
    final menu = <String, _MenuSales>{};
    for (final item in sales) {
      for (final product in item.summary.topProducts) {
        final current = menu[product.name];
        menu[product.name] = _MenuSales(
          name: product.name,
          quantity: (current?.quantity ?? 0) + product.quantity,
          sales: (current?.sales ?? 0) + product.sales,
        );
      }
    }
    final menus = menu.values.toList()
      ..sort((a, b) => b.sales.compareTo(a.sales));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PopqSpacing.md),
        children: [
          SegmentedButton<_SalesPeriod>(
            segments: const [
              ButtonSegment(value: _SalesPeriod.day, label: Text('일 매출')),
              ButtonSegment(value: _SalesPeriod.month, label: Text('월 매출')),
            ],
            selected: {_period},
            onSelectionChanged: (selection) {
              setState(() => _period = selection.single);
              _load();
            },
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text('전체 사업장', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: PopqSpacing.sm),
          Card(
            color: PopqPalette.ink,
            child: Padding(
              padding: const EdgeInsets.all(PopqSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('총 매출', style: TextStyle(color: Colors.white70)),
                  Text(
                    sellerWon(netSales),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '완료 주문 $orders건 · 사업장 ${sales.length}곳',
                    style: const TextStyle(color: PopqPalette.lime),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text('사업장별 성과', style: Theme.of(context).textTheme.titleLarge),
          for (final item in sales)
            Card(
              child: ListTile(
                title: Text(item.store.name),
                subtitle: Text('${item.summary.completedOrderCount}건'),
                trailing: Text(sellerWon(item.summary.netSales)),
              ),
            ),
          const SizedBox(height: PopqSpacing.lg),
          Text('메뉴별 매출', style: Theme.of(context).textTheme.titleLarge),
          if (menus.isEmpty)
            const Padding(
              padding: EdgeInsets.all(PopqSpacing.lg),
              child: Text('해당 기간에 집계된 메뉴 매출이 없습니다.'),
            )
          else
            for (final item in menus.take(10))
              ListTile(
                leading: const Icon(Icons.restaurant_menu_rounded),
                title: Text(item.name),
                subtitle: Text('${item.quantity}개 판매'),
                trailing: Text(sellerWon(item.sales)),
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
      final stores = await widget.storeRepository.findAll();
      final now = DateTime.now();
      final from = _period == _SalesPeriod.day
          ? now
          : DateTime(now.year, now.month);
      final summaries = await Future.wait(
        stores.map(
          (store) => widget.analyticsRepository.findSales(
            store.storeId,
            from: from,
            to: now,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _storeSales = [
          for (var index = 0; index < stores.length; index++)
            _StoreSales(stores[index], summaries[index]),
        ];
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
}

class _StoreSales {
  const _StoreSales(this.store, this.summary);

  final SellerStore store;
  final SellerSalesSummary summary;
}

class _MenuSales {
  const _MenuSales({
    required this.name,
    required this.quantity,
    required this.sales,
  });

  final String name;
  final int quantity;
  final int sales;
}
