import 'package:popq_app_core/popq_app_core.dart';

class SellerOrder {
  const SellerOrder({
    required this.orderPublicId,
    required this.storeId,
    required this.storeName,
    required this.orderType,
    required this.status,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.taxAmount,
    required this.serviceFeeAmount,
    required this.totalAmount,
    required this.version,
    required this.items,
  });

  factory SellerOrder.fromJson(Map<String, Object?> json) {
    return SellerOrder(
      orderPublicId: json['orderPublicId'] as String,
      storeId: (json['storeId'] as num).toInt(),
      storeName: json['storeName'] as String,
      orderType: json['orderType'] as String,
      status: json['status'] as String,
      subtotalAmount: (json['subtotalAmount'] as num).toInt(),
      discountAmount: (json['discountAmount'] as num).toInt(),
      taxAmount: (json['taxAmount'] as num).toInt(),
      serviceFeeAmount: (json['serviceFeeAmount'] as num).toInt(),
      totalAmount: (json['totalAmount'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      items: (json['items'] as List<Object?>? ?? const [])
          .map(
            (item) => SellerOrderItem.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  final String orderPublicId;
  final int storeId;
  final String storeName;
  final String orderType;
  final String status;
  final int subtotalAmount;
  final int discountAmount;
  final int taxAmount;
  final int serviceFeeAmount;
  final int totalAmount;
  final int version;
  final List<SellerOrderItem> items;

  int get totalQuantity =>
      items.fold(0, (total, item) => total + item.quantity);

  SellerOrder copyWith({String? status, int? version}) {
    return SellerOrder(
      orderPublicId: orderPublicId,
      storeId: storeId,
      storeName: storeName,
      orderType: orderType,
      status: status ?? this.status,
      subtotalAmount: subtotalAmount,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      serviceFeeAmount: serviceFeeAmount,
      totalAmount: totalAmount,
      version: version ?? this.version,
      items: items,
    );
  }
}

class SellerOrderItem {
  const SellerOrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotalPrice,
    required this.options,
  });

  factory SellerOrderItem.fromJson(Map<String, Object?> json) {
    return SellerOrderItem(
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toInt(),
      itemTotalPrice: (json['itemTotalPrice'] as num).toInt(),
      options: (json['options'] as List<Object?>? ?? const [])
          .map(
            (option) => SellerOrderItemOption.fromJson(
              Map<String, Object?>.from(option as Map),
            ),
          )
          .toList(),
    );
  }

  final String productName;
  final int quantity;
  final int unitPrice;
  final int itemTotalPrice;
  final List<SellerOrderItemOption> options;
}

class SellerOrderItemOption {
  const SellerOrderItemOption({
    required this.groupName,
    required this.name,
    required this.price,
  });

  factory SellerOrderItemOption.fromJson(Map<String, Object?> json) {
    return SellerOrderItemOption(
      groupName: json['optionGroupName'] as String,
      name: json['optionName'] as String,
      price: (json['optionPrice'] as num).toInt(),
    );
  }

  final String groupName;
  final String name;
  final int price;
}

enum SellerOrderCommand {
  accept('accept', 'ACCEPTED'),
  reject('reject', 'REJECTED'),
  prepare('prepare', 'PREPARING'),
  ready('ready', 'READY'),
  complete('complete', 'COMPLETED');

  const SellerOrderCommand(this.path, this.targetStatus);

  final String path;
  final String targetStatus;
}

class SellerOrderSyncResult {
  const SellerOrderSyncResult({
    required this.refreshRequired,
    required this.serverVersion,
    this.order,
  });

  final bool refreshRequired;
  final int serverVersion;
  final SellerOrder? order;
}

abstract interface class SellerOrderRepository {
  Future<List<SellerOrder>> findAll(int storeId, {String? status});

  Future<SellerOrder> findOne(int storeId, String orderPublicId);

  Future<SellerOrderSyncResult> sync(
    int storeId,
    String orderPublicId,
    int knownVersion,
  );

  Future<SellerOrder> transition(
    int storeId,
    String orderPublicId,
    SellerOrderCommand command, {
    String? reason,
  });
}

class ApiSellerOrderRepository implements SellerOrderRepository {
  ApiSellerOrderRepository(this._apiClient);

  final PopqApiClient _apiClient;

  String _basePath(int storeId) => '/api/v1/seller/stores/$storeId/orders';

  @override
  Future<List<SellerOrder>> findAll(int storeId, {String? status}) {
    return _apiClient.get(
      _basePath(storeId),
      query: status == null ? const {} : {'status': status},
      decode: (value) => (value as List<Object?>)
          .map(
            (item) =>
                SellerOrder.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
    );
  }

  @override
  Future<SellerOrder> findOne(int storeId, String orderPublicId) {
    return _apiClient.get(
      '${_basePath(storeId)}/$orderPublicId',
      decode: (value) =>
          SellerOrder.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }

  @override
  Future<SellerOrderSyncResult> sync(
    int storeId,
    String orderPublicId,
    int knownVersion,
  ) {
    return _apiClient.get(
      '${_basePath(storeId)}/$orderPublicId/sync',
      query: {'knownVersion': knownVersion},
      decode: (value) {
        final json = Map<String, Object?>.from(value as Map);
        final order = json['order'];
        return SellerOrderSyncResult(
          refreshRequired: json['refreshRequired'] as bool,
          serverVersion: (json['serverVersion'] as num).toInt(),
          order: order == null
              ? null
              : SellerOrder.fromJson(Map<String, Object?>.from(order as Map)),
        );
      },
    );
  }

  @override
  Future<SellerOrder> transition(
    int storeId,
    String orderPublicId,
    SellerOrderCommand command, {
    String? reason,
  }) {
    return _apiClient.post(
      '${_basePath(storeId)}/$orderPublicId/${command.path}',
      body: {'reason': reason},
      decode: (value) =>
          SellerOrder.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }
}

class MemorySellerOrderRepository implements SellerOrderRepository {
  MemorySellerOrderRepository({List<SellerOrder> orders = const []})
    : _orders = List.of(orders);

  final List<SellerOrder> _orders;

  @override
  Future<List<SellerOrder>> findAll(int storeId, {String? status}) async {
    return List.unmodifiable(
      _orders.where(
        (order) =>
            order.storeId == storeId &&
            (status == null || order.status == status),
      ),
    );
  }

  @override
  Future<SellerOrder> findOne(int storeId, String orderPublicId) async {
    final index = _findIndex(storeId, orderPublicId);
    if (index < 0) throw StateError('order not found in selected store');
    return _orders[index];
  }

  @override
  Future<SellerOrderSyncResult> sync(
    int storeId,
    String orderPublicId,
    int knownVersion,
  ) async {
    final order = await findOne(storeId, orderPublicId);
    final refreshRequired = order.version != knownVersion;
    return SellerOrderSyncResult(
      refreshRequired: refreshRequired,
      serverVersion: order.version,
      order: refreshRequired ? order : null,
    );
  }

  @override
  Future<SellerOrder> transition(
    int storeId,
    String orderPublicId,
    SellerOrderCommand command, {
    String? reason,
  }) async {
    final index = _findIndex(storeId, orderPublicId);
    if (index < 0) throw StateError('order not found in selected store');
    final order = _orders[index];
    final expectedStatus = switch (command) {
      SellerOrderCommand.accept || SellerOrderCommand.reject => 'PLACED',
      SellerOrderCommand.prepare => 'ACCEPTED',
      SellerOrderCommand.ready => 'PREPARING',
      SellerOrderCommand.complete => 'READY',
    };
    if (order.status != expectedStatus) {
      throw StateError('invalid seller order transition');
    }
    final updated = order.copyWith(
      status: command.targetStatus,
      version: order.version + 1,
    );
    _orders[index] = updated;
    return updated;
  }

  int _findIndex(int storeId, String orderPublicId) {
    return _orders.indexWhere(
      (order) =>
          order.storeId == storeId && order.orderPublicId == orderPublicId,
    );
  }
}
