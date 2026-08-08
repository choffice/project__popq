import 'package:popq_app_core/popq_app_core.dart';

class SellerOrder {
  const SellerOrder({
    required this.orderPublicId,
    required this.storeId,
    required this.storeName,
    required this.orderType,
    required this.status,
    this.requestMessage,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.taxAmount,
    required this.serviceFeeAmount,
    required this.totalAmount,
    required this.version,
    required this.items,
    this.createdAt,
    this.acceptedAt,
    this.preparationMinutes,
    this.estimatedReadyAt,
  });

  factory SellerOrder.fromJson(Map<String, Object?> json) {
    return SellerOrder(
      orderPublicId: json['orderPublicId'] as String,
      storeId: (json['storeId'] as num).toInt(),
      storeName: json['storeName'] as String,
      orderType: json['orderType'] as String,
      status: json['status'] as String,
      requestMessage: _nullableString(json['requestMessage']),
      subtotalAmount: (json['subtotalAmount'] as num).toInt(),
      discountAmount: (json['discountAmount'] as num).toInt(),
      taxAmount: (json['taxAmount'] as num).toInt(),
      serviceFeeAmount: (json['serviceFeeAmount'] as num).toInt(),
      totalAmount: (json['totalAmount'] as num).toInt(),
      version: (json['version'] as num).toInt(),
      createdAt: _dateTime(json['createdAt']),
      acceptedAt: _dateTime(json['acceptedAt']),
      preparationMinutes: (json['preparationMinutes'] as num?)?.toInt(),
      estimatedReadyAt: _dateTime(json['estimatedReadyAt']),
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
  final String? requestMessage;
  final int subtotalAmount;
  final int discountAmount;
  final int taxAmount;
  final int serviceFeeAmount;
  final int totalAmount;
  final int version;
  final List<SellerOrderItem> items;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final int? preparationMinutes;
  final DateTime? estimatedReadyAt;

  int get totalQuantity =>
      items.fold(0, (total, item) => total + item.quantity);

  SellerOrder copyWith({
    String? status,
    int? version,
    DateTime? acceptedAt,
    int? preparationMinutes,
    DateTime? estimatedReadyAt,
  }) {
    return SellerOrder(
      orderPublicId: orderPublicId,
      storeId: storeId,
      storeName: storeName,
      orderType: orderType,
      status: status ?? this.status,
      requestMessage: requestMessage,
      subtotalAmount: subtotalAmount,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      serviceFeeAmount: serviceFeeAmount,
      totalAmount: totalAmount,
      version: version ?? this.version,
      items: items,
      createdAt: createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      preparationMinutes: preparationMinutes ?? this.preparationMinutes,
      estimatedReadyAt: estimatedReadyAt ?? this.estimatedReadyAt,
    );
  }

  static DateTime? _dateTime(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }

  static String? _nullableString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
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

class SellerRefund {
  const SellerRefund({
    required this.refundId,
    required this.amount,
    required this.reason,
    required this.requesterType,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.failureCode,
    this.failureMessage,
  });

  factory SellerRefund.fromJson(Map<String, Object?> json) {
    return SellerRefund(
      refundId: (json['refundId'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
      reason: json['reason'] as String,
      requesterType: json['requesterType'] as String,
      status: json['status'] as String,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      failureCode: json['failureCode'] as String?,
      failureMessage: json['failureMessage'] as String?,
    );
  }

  final int refundId;
  final int amount;
  final String reason;
  final String requesterType;
  final String status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? failureCode;
  final String? failureMessage;
}

class SellerPaymentSummary {
  const SellerPaymentSummary({
    required this.orderPublicId,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.approvedAmount,
    required this.refundedAmount,
    required this.refundableAmount,
    required this.refunds,
  });

  factory SellerPaymentSummary.fromJson(Map<String, Object?> json) {
    return SellerPaymentSummary(
      orderPublicId: json['orderPublicId'] as String,
      paymentStatus: json['paymentStatus'] as String,
      paymentMethod: json['paymentMethod'] as String,
      approvedAmount: (json['approvedAmount'] as num).toInt(),
      refundedAmount: (json['refundedAmount'] as num).toInt(),
      refundableAmount: (json['refundableAmount'] as num).toInt(),
      refunds: (json['refunds'] as List<Object?>? ?? const [])
          .map(
            (item) => SellerRefund.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  final String orderPublicId;
  final String paymentStatus;
  final String paymentMethod;
  final int approvedAmount;
  final int refundedAmount;
  final int refundableAmount;
  final List<SellerRefund> refunds;
}

enum SellerOrderCommand {
  accept('accept', 'PREPARING'),
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
  Future<List<SellerOrder>> findAll(
    int storeId, {
    String? status,
    List<String>? statuses,
    DateTime? date,
  });

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
    int? preparationMinutes,
    bool applyAsStoreDefault = false,
  });

  Future<SellerPaymentSummary> findPayment(
    int storeId,
    String orderPublicId,
  );

  Future<SellerPaymentSummary> refund(
    int storeId,
    String orderPublicId, {
    required int amount,
    required String reason,
  });
}

class ApiSellerOrderRepository implements SellerOrderRepository {
  ApiSellerOrderRepository(this._apiClient);

  final PopqApiClient _apiClient;

  String _basePath(int storeId) => '/api/v1/seller/stores/$storeId/orders';

  @override
  Future<List<SellerOrder>> findAll(
    int storeId, {
    String? status,
    List<String>? statuses,
    DateTime? date,
  }) {
    final query = <String, Object?>{};
    if (status != null) query['status'] = status;
    if (status == null && statuses != null && statuses.isNotEmpty) {
      query['statuses'] = statuses.join(',');
    }
    if (date != null) query['date'] = _calendarDate(date);
    return _apiClient.get(
      _basePath(storeId),
      query: query,
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
    int? preparationMinutes,
    bool applyAsStoreDefault = false,
  }) {
    final body = command == SellerOrderCommand.accept
        ? <String, Object?>{
            'preparationMinutes': preparationMinutes ?? 0,
            'applyAsStoreDefault': applyAsStoreDefault,
            'reason': reason,
          }
        : <String, Object?>{'reason': reason};
    return _apiClient.post(
      '${_basePath(storeId)}/$orderPublicId/${command.path}',
      body: body,
      decode: (value) =>
          SellerOrder.fromJson(Map<String, Object?>.from(value as Map)),
    );
  }

  @override
  Future<SellerPaymentSummary> findPayment(
    int storeId,
    String orderPublicId,
  ) {
    return _apiClient.get(
      '${_basePath(storeId)}/$orderPublicId/payment',
      decode: (value) => SellerPaymentSummary.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  @override
  Future<SellerPaymentSummary> refund(
    int storeId,
    String orderPublicId, {
    required int amount,
    required String reason,
  }) {
    return _apiClient.post(
      '${_basePath(storeId)}/$orderPublicId/refunds',
      body: {'amount': amount, 'reason': reason},
      decode: (value) => SellerPaymentSummary.fromJson(
        Map<String, Object?>.from(value as Map),
      ),
    );
  }
}

class MemorySellerOrderRepository implements SellerOrderRepository {
  MemorySellerOrderRepository({
    List<SellerOrder> orders = const [],
    Map<String, SellerPaymentSummary> payments = const {},
  }) : _orders = List.of(orders),
       _payments = Map.of(payments);

  final List<SellerOrder> _orders;
  final Map<String, SellerPaymentSummary> _payments;

  @override
  Future<List<SellerOrder>> findAll(
    int storeId, {
    String? status,
    List<String>? statuses,
    DateTime? date,
  }) async {
    final DateTime? fromUtc = date == null
        ? null
        : DateTime.utc(date.year, date.month, date.day)
            .subtract(const Duration(hours: 9));
    final DateTime? toUtc = fromUtc?.add(const Duration(days: 1));
    final values =
      _orders.where(
        (order) =>
            order.storeId == storeId &&
            (status == null || order.status == status) &&
            (statuses == null || statuses.contains(order.status)) &&
            (fromUtc == null ||
                order.createdAt != null &&
                    !order.createdAt!.toUtc().isBefore(fromUtc) &&
                    order.createdAt!.toUtc().isBefore(toUtc!)),
      ).toList()
        ..sort((left, right) {
          final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightDate.compareTo(leftDate);
        });
    return List.unmodifiable(values);
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
    int? preparationMinutes,
    bool applyAsStoreDefault = false,
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
    final now = DateTime.now().toUtc();
    final updated = order.copyWith(
      status: command.targetStatus,
      version: order.version + 1,
      acceptedAt: command == SellerOrderCommand.accept ? now : null,
      preparationMinutes:
          command == SellerOrderCommand.accept ? preparationMinutes ?? 0 : null,
      estimatedReadyAt: command == SellerOrderCommand.accept
          ? now.add(Duration(minutes: preparationMinutes ?? 0))
          : null,
    );
    _orders[index] = updated;
    return updated;
  }

  @override
  Future<SellerPaymentSummary> findPayment(
    int storeId,
    String orderPublicId,
  ) async {
    final order = await findOne(storeId, orderPublicId);
    final existing = _payments[orderPublicId];
    if (existing != null) return existing;
    if (order.status != 'COMPLETED') {
      throw StateError('payment is only available for a completed order');
    }
    final created = SellerPaymentSummary(
      orderPublicId: orderPublicId,
      paymentStatus: 'PAID',
      paymentMethod: 'CARD',
      approvedAmount: order.totalAmount,
      refundedAmount: 0,
      refundableAmount: order.totalAmount,
      refunds: const [],
    );
    _payments[orderPublicId] = created;
    return created;
  }

  @override
  Future<SellerPaymentSummary> refund(
    int storeId,
    String orderPublicId, {
    required int amount,
    required String reason,
  }) async {
    final order = await findOne(storeId, orderPublicId);
    final payment = await findPayment(storeId, orderPublicId);
    if (order.status != 'COMPLETED' ||
        payment.paymentStatus != 'PAID' ||
        amount != payment.approvedAmount ||
        reason.trim().isEmpty) {
      throw StateError('refund is not allowed');
    }
    final now = DateTime.now().toUtc();
    final updated = SellerPaymentSummary(
      orderPublicId: orderPublicId,
      paymentStatus: 'REFUNDED',
      paymentMethod: payment.paymentMethod,
      approvedAmount: payment.approvedAmount,
      refundedAmount: amount,
      refundableAmount: 0,
      refunds: [
        ...payment.refunds,
        SellerRefund(
          refundId: payment.refunds.length + 1,
          amount: amount,
          reason: reason.trim(),
          requesterType: 'SELLER',
          status: 'SUCCEEDED',
          requestedAt: now,
          completedAt: now,
        ),
      ],
    );
    _payments[orderPublicId] = updated;
    return updated;
  }

  int _findIndex(int storeId, String orderPublicId) {
    return _orders.indexWhere(
      (order) =>
          order.storeId == storeId && order.orderPublicId == orderPublicId,
    );
  }
}

String _calendarDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
