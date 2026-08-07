import 'package:popq_app_core/popq_app_core.dart';

import '../orders/seller_order_repository.dart';
import '../reviews/seller_review_repository.dart';

class SellerChatAlert {
  const SellerChatAlert({
    required this.storeId,
    required this.storeName,
    required this.orderPublicId,
    required this.customerName,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  factory SellerChatAlert.fromJson(Map<String, Object?> json) {
    return SellerChatAlert(
      storeId: (json['storeId'] as num).toInt(),
      storeName: json['storeName'] as String,
      orderPublicId: json['orderPublicId'] as String,
      customerName: json['customerName'] as String,
      lastMessage: json['lastMessage'] as String,
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
    );
  }

  final int storeId;
  final String storeName;
  final String orderPublicId;
  final String customerName;
  final String lastMessage;
  final DateTime lastMessageAt;
}

class SellerOperationalAlerts {
  const SellerOperationalAlerts({
    required this.orders,
    required this.chats,
    required this.reviews,
  });

  factory SellerOperationalAlerts.fromJson(Map<String, Object?> json) {
    return SellerOperationalAlerts(
      orders: _list(json['orders'])
          .map((item) => SellerOrder.fromJson(_map(item)))
          .take(30)
          .toList(),
      chats: _list(json['chats'])
          .map((item) => SellerChatAlert.fromJson(_map(item)))
          .take(30)
          .toList(),
      reviews: _list(json['reviews'])
          .map((item) => SellerReview.fromJson(_map(item)))
          .take(30)
          .toList(),
    );
  }

  final List<SellerOrder> orders;
  final List<SellerChatAlert> chats;
  final List<SellerReview> reviews;

  static List<Object?> _list(Object? value) =>
      value is List<Object?> ? value : const <Object?>[];

  static Map<String, Object?> _map(Object? value) =>
      Map<String, Object?>.from(value as Map);
}

abstract interface class SellerOperationalAlertRepository {
  Future<SellerOperationalAlerts> findAll({int limit = 30});
}

class ApiSellerOperationalAlertRepository
    implements SellerOperationalAlertRepository {
  ApiSellerOperationalAlertRepository(this._apiClient);

  final PopqApiClient _apiClient;

  @override
  Future<SellerOperationalAlerts> findAll({int limit = 30}) {
    return _apiClient.get(
      '/api/v1/seller/alerts',
      query: {'limit': limit.clamp(1, 30)},
      decode: (value) => SellerOperationalAlerts.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }
}

class MemorySellerOperationalAlertRepository
    implements SellerOperationalAlertRepository {
  MemorySellerOperationalAlertRepository({
    this.alerts = const SellerOperationalAlerts(
      orders: [],
      chats: [],
      reviews: [],
    ),
  });

  final SellerOperationalAlerts alerts;

  @override
  Future<SellerOperationalAlerts> findAll({int limit = 30}) async {
    final safeLimit = limit.clamp(1, 30).toInt();
    return SellerOperationalAlerts(
      orders: alerts.orders.take(safeLimit).toList(),
      chats: alerts.chats.take(safeLimit).toList(),
      reviews: alerts.reviews.take(safeLimit).toList(),
    );
  }
}
