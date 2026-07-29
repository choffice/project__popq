import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import 'customer_order_repository.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.cartController,
    required this.orderRepository,
    super.key,
  });

  final CartController cartController;
  final CustomerOrderRepository orderRepository;

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
        appBar: AppBar(title: const Text('주문 확인')),
        body: const PopqEmptyView(
          title: '주문할 상품이 없어요.',
          description: '장바구니에 상품을 먼저 담아주세요.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('주문 확인')),
      body: ListView(
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: [
          Text('포장 주문', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: PopqSpacing.sm),
          const Text('현재 9.3에서는 TAKEOUT 주문으로 접수합니다.'),
          const SizedBox(height: PopqSpacing.lg),
          for (final item in widget.cartController.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.product.name),
              subtitle: Text(
                [
                  if (item.options.isNotEmpty)
                    item.options.map((option) => option.name).join(', '),
                  '${item.quantity}개',
                ].join(' · '),
              ),
              trailing: Text(_won(item.totalPrice)),
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
              color: PopqPalette.lime.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '개발 단계의 TestPaymentProvider로 결제됩니다. 실제 결제 수단은 외부 PG 확정 후 교체합니다.',
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: PopqSpacing.md),
            Text(
              _errorMessage!,
              style: const TextStyle(color: PopqPalette.coral),
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
                  ? '주문을 처리하고 있어요...'
                  : '${_won(widget.cartController.totalAmount)} 결제',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    final storeId = widget.cartController.storeId;
    if (storeId == null) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final created =
          _createdOrder ??
          await widget.orderRepository.create(
            storeId: storeId,
            items: List.unmodifiable(widget.cartController.items),
            idempotencyKey: _orderIdempotencyKey,
          );
      _createdOrder = created;
      final paid = await widget.orderRepository.confirmPayment(
        created,
        idempotencyKey: _paymentIdempotencyKey,
      );
      widget.cartController.clear();
      if (!mounted) return;
      context.go('${CustomerRoutes.orders}/${paid.orderPublicId}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = '주문 또는 결제를 완료하지 못했습니다. 다시 시도해 주세요.';
      });
    }
  }

  String _key(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
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
