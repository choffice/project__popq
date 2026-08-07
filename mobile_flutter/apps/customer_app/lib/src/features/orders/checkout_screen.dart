import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import 'customer_order_repository.dart';
import 'toss_payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.cartController,
    required this.orderRepository,
    required this.tossClientKey,
    super.key,
  });

  final CartController cartController;
  final CustomerOrderRepository orderRepository;
  final String tossClientKey;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final String _orderIdempotencyKey = _key('order');
  late final String _paymentIdempotencyKey = _key('payment');

  CustomerOrder? _createdOrder;

  var _busy = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    if (widget.cartController.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('주문 확인'),
        ),
        body: const PopqEmptyView(
          title: '주문할 상품이 없어요.',
          description: '장바구니에 상품을 먼저 담아주세요.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 확인'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: [
          Text(
            '포장 주문',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: PopqSpacing.sm),
          const Text(
            '현재 TAKEOUT 주문으로 접수합니다.',
          ),
          const SizedBox(height: PopqSpacing.lg),

          for (final item in widget.cartController.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.product.name),
              subtitle: Text(
                [
                  if (item.options.isNotEmpty)
                    item.options
                        .map((option) => option.name)
                        .join(', '),
                  '${item.quantity}개',
                ].join(' · '),
              ),
              trailing: Text(
                _won(item.totalPrice),
              ),
            ),

          const Divider(),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('결제 금액'),
            trailing: Text(
              _won(widget.cartController.totalAmount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),

          const SizedBox(height: PopqSpacing.md),

          Container(
            padding: const EdgeInsets.all(PopqSpacing.md),
            decoration: BoxDecoration(
              color: PopqPalette.lime.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '토스페이먼츠 테스트 결제창으로 진행됩니다. '
                  '테스트 키를 사용하므로 실제 금액은 결제되지 않습니다.',
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: PopqSpacing.md),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: PopqPalette.coral,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: FilledButton(
            onPressed: _busy ? null : _placeOrder,
            child: Text(
              _busy
                  ? '결제를 준비하고 있어요...'
                  : '${_won(widget.cartController.totalAmount)} 결제',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    final storeId = widget.cartController.storeId;

    if (storeId == null) {
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      if (widget.tossClientKey.trim().isEmpty) {
        throw StateError(
          '토스페이먼츠 클라이언트 키가 설정되지 않았습니다.',
        );
      }

      /*
       * 한 번 생성한 주문은 결제 재시도 시 다시 생성하지 않습니다.
       */
      final created =
          _createdOrder ??
              await widget.orderRepository.create(
                storeId: storeId,
                items: List.unmodifiable(
                  widget.cartController.items,
                ),
                idempotencyKey: _orderIdempotencyKey,
              );

      _createdOrder = created;

      if (!mounted) {
        return;
      }

      /*
       * 토스 결제 인증 화면을 엽니다.
       *
       * 아직 이 시점에는 최종 결제 승인이 된 것이 아닙니다.
       * 인증 성공 후 paymentKey를 Spring Boot에 전달해야
       * 최종 승인이 완료됩니다.
       */
      final tossResult =
      await Navigator.of(context).push<TossPaymentResult>(
        MaterialPageRoute(
          builder: (_) {
            return TossPaymentScreen(
              clientKey: widget.tossClientKey,
              orderId: created.orderPublicId,
              orderName: _buildOrderName(created),
              amount: created.totalAmount,
            );
          },
        ),
      );

      if (!mounted) {
        return;
      }

      /*
       * 사용자가 결제 화면의 뒤로 가기를 누른 경우입니다.
       */
      if (tossResult == null) {
        setState(() {
          _busy = false;
          _errorMessage = '결제가 취소되었습니다.';
        });
        return;
      }

      /*
       * 토스 결제 인증 단계에서 실패한 경우입니다.
       */
      if (!tossResult.success) {
        setState(() {
          _busy = false;
          _errorMessage =
              tossResult.errorMessage ??
                  '결제 인증에 실패했습니다.';
        });
        return;
      }

      final paymentKey = tossResult.paymentKey;

      if (paymentKey == null || paymentKey.isEmpty) {
        throw StateError(
          '토스페이먼츠 paymentKey가 없습니다.',
        );
      }

      /*
       * 토스에서 받은 paymentKey를 POPQ 백엔드로 전달합니다.
       *
       * Spring Boot가 주문번호와 금액을 검증한 뒤
       * 토스페이먼츠 승인 API를 호출합니다.
       */
      final paid =
      await widget.orderRepository.confirmPayment(
        created,
        idempotencyKey: _paymentIdempotencyKey,
        paymentKey: paymentKey,
      );

      widget.cartController.clear();

      if (!mounted) {
        return;
      }

      context.go(
        '${CustomerRoutes.orders}/${paid.orderPublicId}',
      );
    } catch (error, stackTrace) {
      debugPrint('주문·결제 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _errorMessage = _resolveErrorMessage(error);
      });
    }
  }

  String _buildOrderName(CustomerOrder order) {
    if (order.items.isEmpty) {
      return 'POPQ 주문';
    }

    final firstProductName =
        order.items.first.productName;

    if (order.items.length == 1) {
      return firstProductName;
    }

    return '$firstProductName 외 ${order.items.length - 1}건';
  }

  String _resolveErrorMessage(Object error) {
    final message = error.toString();

    if (message.contains(
      '토스페이먼츠 클라이언트 키',
    )) {
      return '토스페이먼츠 클라이언트 키가 설정되지 않았습니다. '
          '고객 앱 실행 설정을 확인해주세요.';
    }

    if (message.contains('paymentKey')) {
      return '결제 인증 정보가 올바르지 않습니다. '
          '다시 시도해주세요.';
    }

    return '주문 또는 결제를 완료하지 못했습니다.\n$message';
  }

  String _key(String prefix) {
    return '$prefix-'
        '${DateTime.now().microsecondsSinceEpoch}';
  }
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 &&
        (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return '$buffer원';
}