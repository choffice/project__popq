import 'package:popq_app_core/popq_app_core.dart';

class SellerSalesSummary {
  const SellerSalesSummary({
    required this.storeId,
    required this.from,
    required this.to,
    required this.netSales,
    required this.completedOrderCount,
    required this.averageOrderAmount,
    required this.dineInSales,
    required this.takeoutSales,
    required this.topProducts,
  });

  factory SellerSalesSummary.fromJson(int storeId, Map<String, Object?> json) {
    return SellerSalesSummary(
      storeId: storeId,
      from: json['from'] as String,
      to: json['to'] as String,
      netSales: (json['netSales'] as num).toInt(),
      completedOrderCount: (json['completedOrderCount'] as num).toInt(),
      averageOrderAmount: (json['averageOrderAmount'] as num).toInt(),
      dineInSales: (json['dineInSales'] as num).toInt(),
      takeoutSales: (json['takeoutSales'] as num).toInt(),
      topProducts: (json['topProducts'] as List<Object?>? ?? const [])
          .map(
            (item) => SellerTopProduct.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  final int storeId;
  final String from;
  final String to;
  final int netSales;
  final int completedOrderCount;
  final int averageOrderAmount;
  final int dineInSales;
  final int takeoutSales;
  final List<SellerTopProduct> topProducts;
}

class SellerTopProduct {
  const SellerTopProduct({
    required this.name,
    required this.quantity,
    required this.sales,
  });

  factory SellerTopProduct.fromJson(Map<String, Object?> json) {
    return SellerTopProduct(
      name: json['productName'] as String,
      quantity: (json['quantity'] as num).toInt(),
      sales: (json['sales'] as num).toInt(),
    );
  }

  final String name;
  final int quantity;
  final int sales;
}

abstract interface class SellerAnalyticsRepository {
  Future<SellerSalesSummary> findSales(
    int storeId, {
    required DateTime from,
    required DateTime to,
  });
}

class ApiSellerAnalyticsRepository implements SellerAnalyticsRepository {
  ApiSellerAnalyticsRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<SellerSalesSummary> findSales(
    int storeId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _apiClient.get(
      '/api/v1/seller/stores/$storeId/analytics/sales',
      query: {'from': _date(from), 'to': _date(to)},
      decode: (value) => SellerSalesSummary.fromJson(
        storeId,
        Map<String, Object?>.from(value as Map),
      ),
    );
  }
}

class MemorySellerAnalyticsRepository implements SellerAnalyticsRepository {
  MemorySellerAnalyticsRepository({
    Map<int, SellerSalesSummary> summaries = const {},
  }) : _summaries = Map.of(summaries);

  final Map<int, SellerSalesSummary> _summaries;

  @override
  Future<SellerSalesSummary> findSales(
    int storeId, {
    required DateTime from,
    required DateTime to,
  }) async {
    return _summaries[storeId] ??
        SellerSalesSummary(
          storeId: storeId,
          from: _date(from),
          to: _date(to),
          netSales: 0,
          completedOrderCount: 0,
          averageOrderAmount: 0,
          dineInSales: 0,
          takeoutSales: 0,
          topProducts: const [],
        );
  }
}

String _date(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
