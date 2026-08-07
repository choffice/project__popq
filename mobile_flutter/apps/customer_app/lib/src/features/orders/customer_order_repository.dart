import 'package:popq_app_core/popq_app_core.dart';

import '../cart/cart_controller.dart';
import 'kakao_payment_models.dart';

class CustomerOrder {
  const CustomerOrder({
    required this.orderPublicId,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.totalAmount,
    required this.version,
    required this.items,
  });

  factory CustomerOrder.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerOrder(
      orderPublicId:
      json['orderPublicId'] as String,
      storeId:
      (json['storeId'] as num).toInt(),
      storeName:
      json['storeName'] as String,
      status:
      json['status'] as String,
      totalAmount:
      (json['totalAmount'] as num).toInt(),
      version:
      (json['version'] as num).toInt(),
      items:
      (json['items'] as List<Object?>? ??
          const [])
          .map(
            (item) =>
            CustomerOrderItem.fromJson(
              Map<String, Object?>.from(
                item as Map,
              ),
            ),
      )
          .toList(),
    );
  }

  final String orderPublicId;
  final int storeId;
  final String storeName;
  final String status;
  final int totalAmount;
  final int version;
  final List<CustomerOrderItem> items;
}

class CustomerOrderItem {
  const CustomerOrderItem({
    required this.productName,
    required this.quantity,
    required this.itemTotalPrice,
  });

  factory CustomerOrderItem.fromJson(
      Map<String, Object?> json,
      ) {
    return CustomerOrderItem(
      productName:
      json['productName'] as String,
      quantity:
      (json['quantity'] as num).toInt(),
      itemTotalPrice:
      (json['itemTotalPrice'] as num)
          .toInt(),
    );
  }

  final String productName;
  final int quantity;
  final int itemTotalPrice;
}

class OrderSyncResult {
  const OrderSyncResult({
    required this.refreshRequired,
    required this.serverVersion,
    this.order,
  });

  final bool refreshRequired;
  final int serverVersion;
  final CustomerOrder? order;
}

abstract interface class CustomerOrderRepository {
  Future<CustomerOrder> create({
    required int storeId,
    required List<CartItem> items,
    required String idempotencyKey,
  });

  Future<CustomerOrder> confirmPayment(
      CustomerOrder order, {
        required String idempotencyKey,
        String? paymentKey,
      });

  Future<KakaoPaymentPreparation>
  prepareKakaoPayment(
      CustomerOrder order, {
        required String idempotencyKey,
      });

  Future<KakaoPaymentApproval>
  approveKakaoPayment(
      CustomerOrder order, {
        required int paymentId,
        required String pgToken,
      });

  Future<List<CustomerOrder>> findAll();

  Future<CustomerOrder> findOne(
      String orderPublicId,
      );

  Future<OrderSyncResult> sync(
      String orderPublicId,
      int knownVersion,
      );
}

class ApiCustomerOrderRepository
    implements CustomerOrderRepository {
  ApiCustomerOrderRepository(
      this._apiClient,
      );

  final PopqApiClient _apiClient;

  @override
  Future<CustomerOrder> create({
    required int storeId,
    required List<CartItem> items,
    required String idempotencyKey,
  }) {
    return _apiClient.post(
      '/api/v1/customer/orders/stores/$storeId',
      body: {
        'idempotencyKey': idempotencyKey,
        'orderType': 'TAKEOUT',
        'items':
        items
            .map(
              (item) => {
            'productId':
            item.product.productId,
            'quantity': item.quantity,
            'optionIds':
            item.options
                .map(
                  (option) =>
              option.optionId,
            )
                .toList(),
          },
        )
            .toList(),
      },
      decode:
          (value) => CustomerOrder.fromJson(
        Map<String, Object?>.from(
          value as Map,
        ),
      ),
    );
  }

  @override
  Future<CustomerOrder> confirmPayment(
      CustomerOrder order, {
        required String idempotencyKey,
        String? paymentKey,
      }) async {
    await _apiClient
        .post<Map<String, Object?>>(
      '/api/v1/customer/orders/'
          '${order.orderPublicId}/payments',
      body: {
        'idempotencyKey':
        idempotencyKey,
        'simulateFailure': false,
        'paymentKey': paymentKey,
      },
      decode:
          (value) =>
      Map<String, Object?>.from(
        value as Map,
      ),
    );

    return findOne(order.orderPublicId);
  }

  @override
  Future<KakaoPaymentPreparation>
  prepareKakaoPayment(
      CustomerOrder order, {
        required String idempotencyKey,
      }) {
    return _apiClient.post(
      '/api/v1/customer/orders/'
          '${order.orderPublicId}'
          '/payments/kakao/prepare',
      body: {
        'idempotencyKey':
        idempotencyKey,
      },
      decode:
          (value) =>
          KakaoPaymentPreparation.fromJson(
            Map<String, Object?>.from(
              value as Map,
            ),
          ),
    );
  }

  @override
  Future<KakaoPaymentApproval>
  approveKakaoPayment(
      CustomerOrder order, {
        required int paymentId,
        required String pgToken,
      }) {
    return _apiClient.post(
      '/api/v1/customer/orders/'
          '${order.orderPublicId}'
          '/payments/kakao/approve',
      body: {
        'paymentId': paymentId,
        'pgToken': pgToken,
      },
      decode:
          (value) =>
          KakaoPaymentApproval.fromJson(
            Map<String, Object?>.from(
              value as Map,
            ),
          ),
    );
  }

  @override
  Future<List<CustomerOrder>> findAll() {
    return _apiClient.get(
      '/api/v1/customer/orders',
      decode: (value) {
        return (value as List<Object?>)
            .map(
              (item) =>
              CustomerOrder.fromJson(
                Map<String, Object?>.from(
                  item as Map,
                ),
              ),
        )
            .toList();
      },
    );
  }

  @override
  Future<CustomerOrder> findOne(
      String orderPublicId,
      ) {
    return _apiClient.get(
      '/api/v1/customer/orders/'
          '$orderPublicId',
      decode:
          (value) => CustomerOrder.fromJson(
        Map<String, Object?>.from(
          value as Map,
        ),
      ),
    );
  }

  @override
  Future<OrderSyncResult> sync(
      String orderPublicId,
      int knownVersion,
      ) {
    return _apiClient.get(
      '/api/v1/customer/orders/'
          '$orderPublicId/sync',
      query: {
        'knownVersion': knownVersion,
      },
      decode: (value) {
        final json =
        Map<String, Object?>.from(
          value as Map,
        );

        final order = json['order'];

        return OrderSyncResult(
          refreshRequired:
          json['refreshRequired'] as bool,
          serverVersion:
          (json['serverVersion'] as num)
              .toInt(),
          order:
          order == null
              ? null
              : CustomerOrder.fromJson(
            Map<String, Object?>.from(
              order as Map,
            ),
          ),
        );
      },
    );
  }
}

class MemoryCustomerOrderRepository
    implements CustomerOrderRepository {
  MemoryCustomerOrderRepository({
    List<CustomerOrder> orders = const [],
  }) : _orders = List.of(orders);

  final List<CustomerOrder> _orders;

  final Map<String, KakaoPaymentPreparation>
  _kakaoPreparations = {};

  final Map<String, String>
  _kakaoIdempotencyKeys = {};

  var _nextPaymentId = 1;

  @override
  Future<CustomerOrder> create({
    required int storeId,
    required List<CartItem> items,
    required String idempotencyKey,
  }) async {
    final order = CustomerOrder(
      orderPublicId:
      'memory-order-${_orders.length + 1}',
      storeId: storeId,
      storeName: '성수 커피 연구소',
      status: 'CREATED',
      totalAmount:
      items.fold(
        0,
            (sum, item) =>
        sum + item.totalPrice,
      ),
      version: 0,
      items:
      items
          .map(
            (item) =>
            CustomerOrderItem(
              productName:
              item.product.name,
              quantity:
              item.quantity,
              itemTotalPrice:
              item.totalPrice,
            ),
      )
          .toList(),
    );

    _orders.insert(0, order);

    return order;
  }

  @override
  Future<CustomerOrder> confirmPayment(
      CustomerOrder order, {
        required String idempotencyKey,
        String? paymentKey,
      }) async {
    return _markPlaced(order);
  }

  @override
  Future<KakaoPaymentPreparation>
  prepareKakaoPayment(
      CustomerOrder order, {
        required String idempotencyKey,
      }) async {
    final existing =
    _kakaoPreparations[
    order.orderPublicId];

    if (existing != null) {
      final existingKey =
      _kakaoIdempotencyKeys[
      order.orderPublicId];

      if (existingKey != idempotencyKey) {
        throw StateError(
          '다른 멱등성 키로 시작된 '
              '카카오페이 결제가 있습니다.',
        );
      }

      return KakaoPaymentPreparation(
        paymentId: existing.paymentId,
        orderPublicId:
        existing.orderPublicId,
        provider: existing.provider,
        status: existing.status,
        amount: existing.amount,
        redirectUrl:
        existing.redirectUrl,
        expiresAt: existing.expiresAt,
        reused: true,
      );
    }

    final preparation =
    KakaoPaymentPreparation(
      paymentId: _nextPaymentId++,
      orderPublicId:
      order.orderPublicId,
      provider: 'KAKAO_PAY',
      status: 'IN_PROGRESS',
      amount: order.totalAmount,
      redirectUrl:
      'https://example.test/'
          'kakao-pay'
          '?orderPublicId='
          '${order.orderPublicId}',
      expiresAt:
      DateTime.now().add(
        const Duration(
          minutes: 15,
        ),
      ),
      reused: false,
    );

    _kakaoPreparations[
    order.orderPublicId] =
        preparation;

    _kakaoIdempotencyKeys[
    order.orderPublicId] =
        idempotencyKey;

    return preparation;
  }

  @override
  Future<KakaoPaymentApproval>
  approveKakaoPayment(
      CustomerOrder order, {
        required int paymentId,
        required String pgToken,
      }) async {
    if (pgToken.trim().isEmpty) {
      throw StateError(
        '카카오페이 pgToken이 없습니다.',
      );
    }

    final preparation =
    _kakaoPreparations[
    order.orderPublicId];

    if (preparation == null ||
        preparation.paymentId != paymentId) {
      throw StateError(
        '카카오페이 결제 준비 정보가 '
            '올바르지 않습니다.',
      );
    }

    final paid = _markPlaced(order);

    _kakaoPreparations[
    order.orderPublicId] =
        KakaoPaymentPreparation(
          paymentId: paymentId,
          orderPublicId:
          order.orderPublicId,
          provider: 'KAKAO_PAY',
          status: 'PAID',
          amount: order.totalAmount,
          redirectUrl: null,
          expiresAt: null,
          reused: false,
        );

    return KakaoPaymentApproval(
      paymentId: paymentId,
      orderPublicId:
      order.orderPublicId,
      provider: 'KAKAO_PAY',
      paymentMethod: 'KAKAO_PAY',
      paymentStatus: 'PAID',
      orderStatus: paid.status,
      approvedAmount:
      paid.totalAmount,
      approvedAt: DateTime.now(),
      reused: false,
    );
  }

  CustomerOrder _markPlaced(
      CustomerOrder order,
      ) {
    final paid = CustomerOrder(
      orderPublicId:
      order.orderPublicId,
      storeId: order.storeId,
      storeName: order.storeName,
      status: 'PLACED',
      totalAmount: order.totalAmount,
      version: order.version + 1,
      items: order.items,
    );

    final index = _orders.indexWhere(
          (candidate) =>
      candidate.orderPublicId ==
          order.orderPublicId,
    );

    if (index < 0) {
      _orders.insert(0, paid);
    } else {
      _orders[index] = paid;
    }

    return paid;
  }

  @override
  Future<List<CustomerOrder>>
  findAll() async {
    return List.unmodifiable(_orders);
  }

  @override
  Future<CustomerOrder> findOne(
      String orderPublicId,
      ) async {
    return _orders.firstWhere(
          (order) =>
      order.orderPublicId ==
          orderPublicId,
    );
  }

  @override
  Future<OrderSyncResult> sync(
      String orderPublicId,
      int knownVersion,
      ) async {
    final order =
    await findOne(orderPublicId);

    return OrderSyncResult(
      refreshRequired:
      order.version != knownVersion,
      serverVersion: order.version,
      order:
      order.version != knownVersion
          ? order
          : null,
    );
  }
}