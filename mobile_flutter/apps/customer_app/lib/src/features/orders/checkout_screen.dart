import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import 'customer_order_repository.dart';
import 'pending_payment_store.dart';
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
  late String _paymentIdempotencyKey = _key('payment');

  final PendingPaymentStore _pendingPaymentStore = PendingPaymentStore();

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
          const Text('현재 TAKEOUT 주문으로 접수합니다.'),
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
              '토스페이먼츠 테스트 결제창으로 진행됩니다. '
              '테스트 키를 사용하므로 실제 금액은 결제되지 않습니다.',
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
                  ? '결제 상태를 확인하고 있어요...'
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
        throw StateError('토스페이먼츠 클라이언트 키가 설정되지 않았습니다.');
      }

      /*
       * 한 번 생성한 주문은 결제 재시도 시 다시 생성하지 않습니다.
       */
      final created =
          _createdOrder ??
          await widget.orderRepository.create(
            storeId: storeId,
            items: List.unmodifiable(widget.cartController.items),
            idempotencyKey: _orderIdempotencyKey,
          );

      _createdOrder = created;

      /*
       * 이전 승인 요청의 결과가 아직 확정되지 않았다면
       * 새 토스 결제창을 열기 전에 반드시 기존 결제부터 확인합니다.
       *
       * 같은 주문의 pending 결제가 PAID면 그대로 주문 상세로 이동하고,
       * 확정 실패면 저장 정보를 비운 뒤 새 paymentKey로 재시도할 수 있습니다.
       * 아직 IN_PROGRESS면 새 결제를 열지 않아 이중 결제를 방지합니다.
       */
      final canStartNewPayment = await _resolvePendingBeforeNewPayment(created);

      if (!canStartNewPayment || !mounted) {
        return;
      }

      /*
       * 토스 결제 인증 화면을 엽니다.
       *
       * 아직 이 시점에는 최종 결제 승인이 된 것이 아닙니다.
       * 인증 성공 후 paymentKey를 Spring Boot에 전달해야
       * 최종 승인이 완료됩니다.
       */
      final tossResult = await Navigator.of(context).push<TossPaymentResult>(
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
          _errorMessage = tossResult.errorMessage ?? '결제 인증에 실패했습니다.';
        });
        return;
      }

      final paymentKey = tossResult.paymentKey;

      if (paymentKey == null || paymentKey.isEmpty) {
        throw StateError('토스페이먼츠 paymentKey가 없습니다.');
      }

      /*
       * 앱이 여기서 종료되어도 다시 복구할 수 있도록
       * 백엔드 승인 요청보다 먼저 pending 결제 정보를 저장합니다.
       *
       * 토스 Secret Key는 저장하지 않으며,
       * 클라이언트가 이미 받은 paymentKey와 POPQ 복구 식별값만 저장합니다.
       */
      final pending = PendingPayment(
        orderPublicId: created.orderPublicId,
        paymentKey: paymentKey,
        idempotencyKey: _paymentIdempotencyKey,
        amount: created.totalAmount,
        savedAt: DateTime.now(),
      );

      await _pendingPaymentStore.save(pending);

      /*
       * 토스에서 받은 paymentKey를 POPQ 백엔드로 전달합니다.
       *
       * Spring Boot가 주문번호와 금액을 검증한 뒤
       * 토스페이먼츠 승인 API를 호출합니다.
       */
      try {
        final paid = await widget.orderRepository.confirmPayment(
          created,
          idempotencyKey: _paymentIdempotencyKey,
          paymentKey: paymentKey,
        );

        await _pendingPaymentStore.clearIfMatches(
          orderPublicId: created.orderPublicId,
          paymentKey: paymentKey,
        );

        widget.cartController.clear();

        if (!mounted) {
          return;
        }

        context.go('${CustomerRoutes.orders}/${paid.orderPublicId}');
      } catch (error, stackTrace) {
        debugPrint('결제 승인 응답 오류: $error');
        debugPrintStack(stackTrace: stackTrace);

        /*
         * 서버에서 승인은 성공했지만 HTTP 응답만 놓친 경우가 있으므로
         * 즉시 한 번 복구 API로 실제 상태를 확인합니다.
         *
         * 복구마저 통신 실패하면 pending 정보를 지우지 않습니다.
         * 다음 시도 또는 다음 앱 실행에서 같은 결제를 다시 확인합니다.
         */
        final recovered = await _tryRecoverPendingPayment(pending);

        if (recovered) {
          return;
        }

        rethrow;
      }
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

  Future<bool> _resolvePendingBeforeNewPayment(CustomerOrder created) async {
    final pending = await _pendingPaymentStore.load();

    if (pending == null) {
      return true;
    }

    if (pending.orderPublicId != created.orderPublicId) {
      final resolvedOtherOrder = await _tryRecoverPendingPayment(
        pending,
        navigateWhenPaid: true,
      );

      if (resolvedOtherOrder) {
        return false;
      }

      throw StateError(
        '이전에 진행한 결제 결과를 아직 확인하고 있습니다. '
        '잠시 후 다시 시도해주세요.',
      );
    }

    if (pending.amount != created.totalAmount) {
      throw StateError(
        '저장된 결제 금액과 현재 주문 금액이 다릅니다. '
        '새 결제를 진행하지 않고 결제 내역을 확인해주세요.',
      );
    }

    /*
     * pending에 저장된 멱등키를 그대로 되살립니다.
     * 앱이 종료되기 전 같은 화면에서 다시 시도하는 경우에도
     * 기존 결제 요청의 식별자가 바뀌지 않습니다.
     */
    _paymentIdempotencyKey = pending.idempotencyKey;

    final recovery = await widget.orderRepository.recoverPayment(
      pending.orderPublicId,
    );

    _validateRecoveryMatchesPending(pending, recovery);

    if (recovery.isPaid) {
      await _finishRecoveredPayment(pending);
      return false;
    }

    if (recovery.isTerminalFailure) {
      await _pendingPaymentStore.clearIfMatches(
        orderPublicId: pending.orderPublicId,
        paymentKey: pending.paymentKey,
      );

      /*
       * 실패가 확정됐을 때만 새 멱등키를 발급합니다.
       * 다음 토스 인증에서 받은 새 paymentKey와 이전 요청이 섞이지 않습니다.
       */
      _paymentIdempotencyKey = _key('payment');
      return true;
    }

    if (recovery.requiresManualReview) {
      throw StateError(
        recovery.failureMessage ??
            '결제 금액이 이미 일부 또는 전부 취소된 상태입니다. '
                '결제 내역을 확인해주세요.',
      );
    }

    throw StateError(
      recovery.failureMessage ??
          '이전 결제 승인 결과를 확인하고 있습니다. '
              '새 결제를 진행하지 않고 잠시 후 다시 확인해주세요.',
    );
  }

  Future<bool> _tryRecoverPendingPayment(
    PendingPayment pending, {
    bool navigateWhenPaid = true,
  }) async {
    try {
      final recovery = await widget.orderRepository.recoverPayment(
        pending.orderPublicId,
      );

      _validateRecoveryMatchesPending(pending, recovery);

      if (recovery.isPaid) {
        if (navigateWhenPaid) {
          await _finishRecoveredPayment(pending);
        }
        return true;
      }

      if (recovery.isTerminalFailure) {
        await _pendingPaymentStore.clearIfMatches(
          orderPublicId: pending.orderPublicId,
          paymentKey: pending.paymentKey,
        );

        _paymentIdempotencyKey = _key('payment');

        if (mounted) {
          setState(() {
            _busy = false;
            _errorMessage =
                recovery.failureMessage ?? '결제 승인이 실패했습니다. 다시 결제해주세요.';
          });
        }

        return true;
      }

      if (mounted) {
        setState(() {
          _busy = false;
          _errorMessage =
              recovery.failureMessage ??
              '결제 결과를 확인하고 있습니다. '
                  '새 결제를 진행하지 말고 잠시 후 다시 확인해주세요.';
        });
      }

      return true;
    } catch (error, stackTrace) {
      debugPrint('결제 복구 확인 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      /*
       * 복구 API 자체가 네트워크 오류라면 성공/실패를 알 수 없습니다.
       * pending 정보를 유지한 채 상위 오류 처리로 넘깁니다.
       */
      return false;
    }
  }

  void _validateRecoveryMatchesPending(
    PendingPayment pending,
    CustomerPaymentRecovery recovery,
  ) {
    final providerPaymentKey = recovery.providerPaymentKey;

    if (recovery.orderPublicId != pending.orderPublicId ||
        recovery.requestedAmount != pending.amount ||
        (providerPaymentKey != null &&
            providerPaymentKey.isNotEmpty &&
            providerPaymentKey != pending.paymentKey)) {
      throw StateError(
        '저장된 결제 정보와 서버 결제 정보가 일치하지 않습니다. '
        '새 결제를 진행하지 말고 주문 내역을 확인해주세요.',
      );
    }
  }

  Future<void> _finishRecoveredPayment(PendingPayment pending) async {
    await _pendingPaymentStore.clearIfMatches(
      orderPublicId: pending.orderPublicId,
      paymentKey: pending.paymentKey,
    );

    widget.cartController.clear();

    if (!mounted) {
      return;
    }

    context.go('${CustomerRoutes.orders}/${pending.orderPublicId}');
  }

  String _buildOrderName(CustomerOrder order) {
    if (order.items.isEmpty) {
      return 'POPQ 주문';
    }

    final firstProductName = order.items.first.productName;

    if (order.items.length == 1) {
      return firstProductName;
    }

    return '$firstProductName 외 ${order.items.length - 1}건';
  }

  String _resolveErrorMessage(Object error) {
    final message = error.toString();

    if (message.contains('토스페이먼츠 클라이언트 키')) {
      return '토스페이먼츠 클라이언트 키가 설정되지 않았습니다. '
          '고객 앱 실행 설정을 확인해주세요.';
    }

    if (message.contains('paymentKey')) {
      return '결제 인증 정보가 올바르지 않습니다. '
          '다시 시도해주세요.';
    }

    if (message.contains('이전에 진행한 결제') ||
        message.contains('이전 결제 승인 결과') ||
        message.contains('결제 결과를 확인') ||
        message.contains('저장된 결제 금액')) {
      return message.replaceFirst('Bad state: ', '');
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
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return '$buffer원';
}
