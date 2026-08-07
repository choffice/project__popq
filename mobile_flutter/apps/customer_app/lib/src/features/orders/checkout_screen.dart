import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import 'customer_order_repository.dart';
import 'customer_payment_provider.dart';
import 'kakao_payment_screen.dart';
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
  State<CheckoutScreen> createState() {
    return _CheckoutScreenState();
  }
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final String _orderIdempotencyKey =
  _key('order');

  late final String _tossPaymentIdempotencyKey =
  _key('toss-payment');

  late final String _kakaoPaymentIdempotencyKey =
  _key('kakao-payment');

  CustomerPaymentProvider _selectedProvider =
      CustomerPaymentProvider.tossPayments;

  /*
   * 결제가 한 번 시작된 뒤에는 다른 결제수단으로 변경하지 않습니다.
   *
   * 특히 카카오페이는 prepare 단계에서 Payment가 생성되므로
   * 같은 주문을 토스 결제로 다시 승인하면 충돌할 수 있습니다.
   */
  CustomerPaymentProvider? _startedProvider;

  CustomerOrder? _createdOrder;

  var _busy = false;
  String? _errorMessage;

  bool get _paymentProviderLocked {
    return _startedProvider != null;
  }

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
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        children: [
          Text(
            '포장 주문',
            style:
            Theme.of(context)
                .textTheme
                .headlineSmall,
          ),
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          const Text(
            '현재 TAKEOUT 주문으로 접수합니다.',
          ),
          const SizedBox(
            height: PopqSpacing.lg,
          ),

          for (final item
          in widget.cartController.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.product.name,
              ),
              subtitle: Text(
                [
                  if (item.options.isNotEmpty)
                    item.options
                        .map(
                          (option) =>
                      option.name,
                    )
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
              _won(
                widget
                    .cartController
                    .totalAmount,
              ),
              style:
              Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
          ),

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          Text(
            '결제수단',
            style:
            Theme.of(context)
                .textTheme
                .titleMedium,
          ),

          const SizedBox(
            height: PopqSpacing.sm,
          ),

          for (final provider
          in CustomerPaymentProvider.values) ...[
            _PaymentProviderCard(
              provider: provider,
              selected:
              _selectedProvider == provider,
              enabled:
              !_busy &&
                  !_paymentProviderLocked,
              onPressed: () {
                _selectProvider(provider);
              },
            ),
            if (provider !=
                CustomerPaymentProvider
                    .values
                    .last)
              const SizedBox(
                height: PopqSpacing.sm,
              ),
          ],

          if (_paymentProviderLocked) ...[
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            Text(
              '${_startedProvider!.label} 결제가 이미 시작되었습니다. '
                  '결제를 다시 시도해도 같은 결제수단으로 진행됩니다.',
              style:
              Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],

          const SizedBox(
            height: PopqSpacing.md,
          ),

          _PaymentInformationBox(
            provider: _selectedProvider,
          ),

          if (_errorMessage != null) ...[
            const SizedBox(
              height: PopqSpacing.md,
            ),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: PopqPalette.coral,
              ),
            ),
          ],

          const SizedBox(
            height: PopqSpacing.lg,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(
            PopqSpacing.md,
          ),
          child: FilledButton(
            onPressed:
            _busy ? null : _placeOrder,
            child: Text(
              _busy
                  ? '${_selectedProvider.label} 결제를 준비하고 있어요...'
                  : '${_won(widget.cartController.totalAmount)} '
                  '${_selectedProvider.label} 결제',
            ),
          ),
        ),
      ),
    );
  }

  void _selectProvider(
      CustomerPaymentProvider provider,
      ) {
    if (_busy ||
        _paymentProviderLocked ||
        provider == _selectedProvider) {
      return;
    }

    setState(() {
      _selectedProvider = provider;
      _errorMessage = null;
    });
  }

  Future<void> _placeOrder() async {
    final storeId =
        widget.cartController.storeId;

    if (storeId == null) {
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      _validateSelectedProvider();

      /*
       * 한 번 생성한 주문은 결제 재시도 시
       * 다시 생성하지 않습니다.
       */
      final created =
          _createdOrder ??
              await widget.orderRepository.create(
                storeId: storeId,
                items: List.unmodifiable(
                  widget.cartController.items,
                ),
                idempotencyKey:
                _orderIdempotencyKey,
              );

      _createdOrder = created;

      if (!mounted) {
        return;
      }

      /*
       * 결제를 시작한 뒤에는 결제수단을 잠급니다.
       */
      setState(() {
        _startedProvider ??=
            _selectedProvider;
      });

      final CustomerOrder? paid =
      switch (_selectedProvider) {
        CustomerPaymentProvider
            .tossPayments =>
        await _payWithToss(created),

        CustomerPaymentProvider
            .kakaoPay =>
        await _payWithKakao(created),
      };

      if (paid == null || !mounted) {
        return;
      }

      widget.cartController.clear();

      context.go(
        '${CustomerRoutes.orders}/'
            '${paid.orderPublicId}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '주문·결제 오류: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _busy = false;
        _errorMessage =
            _resolveErrorMessage(error);
      });
    }
  }

  void _validateSelectedProvider() {
    if (_startedProvider != null &&
        _startedProvider !=
            _selectedProvider) {
      throw StateError(
        '이미 다른 결제수단으로 결제가 시작되었습니다.',
      );
    }

    if (_selectedProvider ==
        CustomerPaymentProvider
            .tossPayments &&
        widget.tossClientKey
            .trim()
            .isEmpty) {
      throw StateError(
        '토스페이먼츠 클라이언트 키가 설정되지 않았습니다.',
      );
    }
  }

  Future<CustomerOrder?> _payWithToss(
      CustomerOrder order,
      ) async {
    final tossResult =
    await Navigator.of(
      context,
    ).push<TossPaymentResult>(
      MaterialPageRoute(
        builder: (_) {
          return TossPaymentScreen(
            clientKey:
            widget.tossClientKey,
            orderId:
            order.orderPublicId,
            orderName:
            _buildOrderName(order),
            amount: order.totalAmount,
          );
        },
      ),
    );

    if (!mounted) {
      return null;
    }

    /*
     * 사용자가 시스템 뒤로 가기로
     * 결제 화면을 닫은 경우입니다.
     */
    if (tossResult == null) {
      _stopPayment(
        '토스페이먼츠 결제 화면을 닫았습니다. '
            '다시 결제할 수 있습니다.',
      );

      return null;
    }

    if (!tossResult.success) {
      _stopPayment(
        tossResult.errorMessage ??
            '토스페이먼츠 결제 인증에 실패했습니다.',
      );

      return null;
    }

    if (tossResult.orderId !=
        order.orderPublicId) {
      throw StateError(
        '토스페이먼츠 주문번호가 '
            '현재 주문과 일치하지 않습니다.',
      );
    }

    if (tossResult.amount !=
        order.totalAmount) {
      throw StateError(
        '토스페이먼츠 결제 금액이 '
            '현재 주문 금액과 일치하지 않습니다.',
      );
    }

    final paymentKey =
        tossResult.paymentKey;

    if (paymentKey == null ||
        paymentKey.trim().isEmpty) {
      throw StateError(
        '토스페이먼츠 paymentKey가 없습니다.',
      );
    }

    return widget.orderRepository
        .confirmPayment(
      order,
      idempotencyKey:
      _tossPaymentIdempotencyKey,
      paymentKey: paymentKey,
    );
  }

  Future<CustomerOrder?> _payWithKakao(
      CustomerOrder order,
      ) async {
    /*
     * POPQ 백엔드가 카카오페이 ready API를 호출하고
     * tid와 결제창 이동 URL을 저장합니다.
     */
    final preparation =
    await widget.orderRepository
        .prepareKakaoPayment(
      order,
      idempotencyKey:
      _kakaoPaymentIdempotencyKey,
    );

    if (preparation.orderPublicId !=
        order.orderPublicId) {
      throw StateError(
        '카카오페이 준비 주문번호가 '
            '현재 주문과 일치하지 않습니다.',
      );
    }

    if (preparation.provider !=
        'KAKAO_PAY') {
      throw StateError(
        '카카오페이로 준비된 결제가 아닙니다.',
      );
    }

    if (preparation.amount !=
        order.totalAmount) {
      throw StateError(
        '카카오페이 준비 금액이 '
            '현재 주문 금액과 일치하지 않습니다.',
      );
    }

    /*
     * 이전 요청에서 이미 승인까지 끝난 경우입니다.
     */
    if (preparation.isPaid) {
      return widget.orderRepository.findOne(
        order.orderPublicId,
      );
    }

    if (!preparation.canOpenPaymentPage) {
      throw StateError(
        '카카오페이 결제 이동 주소가 없습니다.',
      );
    }

    final expiresAt =
        preparation.expiresAt;

    if (expiresAt != null &&
        !DateTime.now()
            .toUtc()
            .isBefore(
          expiresAt.toUtc(),
        )) {
      throw StateError(
        '카카오페이 결제 준비 시간이 만료되었습니다. '
            '다시 시도해주세요.',
      );
    }

    final redirectUrl =
        preparation.redirectUrl;

    if (redirectUrl == null ||
        redirectUrl.trim().isEmpty) {
      throw StateError(
        '카카오페이 결제 이동 주소가 없습니다.',
      );
    }

    final kakaoResult =
    await Navigator.of(
      context,
    ).push<KakaoPaymentResult>(
      MaterialPageRoute(
        builder: (_) {
          return KakaoPaymentScreen(
            redirectUrl: redirectUrl,
            orderPublicId:
            order.orderPublicId,
            paymentId:
            preparation.paymentId,
          );
        },
      ),
    );

    if (!mounted) {
      return null;
    }

    /*
     * 사용자가 시스템 뒤로 가기로
     * 결제 화면을 닫은 경우입니다.
     */
    if (kakaoResult == null) {
      _stopPayment(
        '카카오페이 결제 화면을 닫았습니다. '
            '같은 결제수단으로 다시 시도할 수 있습니다.',
      );

      return null;
    }

    if (kakaoResult.canceled) {
      _stopPayment(
        kakaoResult.errorMessage ??
            '카카오페이 결제가 취소되었습니다.',
      );

      return null;
    }

    if (!kakaoResult.success) {
      _stopPayment(
        kakaoResult.errorMessage ??
            '카카오페이 결제 인증에 실패했습니다.',
      );

      return null;
    }

    if (kakaoResult.orderPublicId !=
        order.orderPublicId) {
      throw StateError(
        '카카오페이 콜백 주문번호가 '
            '현재 주문과 일치하지 않습니다.',
      );
    }

    if (kakaoResult.paymentId !=
        preparation.paymentId) {
      throw StateError(
        '카카오페이 콜백 결제번호가 '
            '현재 결제와 일치하지 않습니다.',
      );
    }

    final pgToken =
        kakaoResult.pgToken;

    if (pgToken == null ||
        pgToken.trim().isEmpty) {
      throw StateError(
        '카카오페이 pgToken이 없습니다.',
      );
    }

    /*
     * 카카오페이 인증 완료 후 pgToken을
     * POPQ 백엔드로 보내 최종 승인을 요청합니다.
     */
    final approval =
    await widget.orderRepository
        .approveKakaoPayment(
      order,
      paymentId:
      preparation.paymentId,
      pgToken: pgToken,
    );

    if (approval.paymentId !=
        preparation.paymentId) {
      throw StateError(
        '카카오페이 승인 결제번호가 '
            '준비된 결제와 일치하지 않습니다.',
      );
    }

    if (approval.orderPublicId !=
        order.orderPublicId) {
      throw StateError(
        '카카오페이 승인 주문번호가 '
            '현재 주문과 일치하지 않습니다.',
      );
    }

    if (approval.provider !=
        'KAKAO_PAY' ||
        approval.paymentMethod !=
            'KAKAO_PAY') {
      throw StateError(
        '카카오페이 승인 결제수단 정보가 '
            '올바르지 않습니다.',
      );
    }

    if (!approval.isPaid) {
      throw StateError(
        '카카오페이 승인이 완료되지 않았습니다.',
      );
    }

    if (approval.approvedAmount !=
        order.totalAmount) {
      throw StateError(
        '카카오페이 승인 금액이 '
            '현재 주문 금액과 일치하지 않습니다.',
      );
    }

    return widget.orderRepository.findOne(
      order.orderPublicId,
    );
  }

  void _stopPayment(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      _errorMessage = message;
    });
  }

  String _buildOrderName(
      CustomerOrder order,
      ) {
    if (order.items.isEmpty) {
      return 'POPQ 주문';
    }

    final firstProductName =
        order.items.first.productName;

    if (order.items.length == 1) {
      return firstProductName;
    }

    return '$firstProductName 외 '
        '${order.items.length - 1}건';
  }

  String _resolveErrorMessage(
      Object error,
      ) {
    if (error is NetworkFailure) {
      return error.message;
    }

    if (error is AuthenticationFailure) {
      return error.message;
    }

    if (error is ApiRequestFailure) {
      return error.message;
    }

    if (error is InvalidResponseFailure) {
      return error.message;
    }

    final message = error.toString();

    if (message.contains(
      '토스페이먼츠 클라이언트 키',
    )) {
      return '토스페이먼츠 클라이언트 키가 설정되지 않았습니다. '
          '고객 앱 실행 설정을 확인해주세요.';
    }

    if (message.contains(
      'paymentKey',
    )) {
      return '토스페이먼츠 결제 인증 정보가 올바르지 않습니다. '
          '다시 시도해주세요.';
    }

    if (message.contains(
      'KAKAO_SECRET_KEY',
    ) ||
        message.contains(
          'Secret key',
        )) {
      return '카카오페이 개발용 Secret key가 설정되지 않았습니다. '
          'Spring Boot 실행 환경변수를 확인해주세요.';
    }

    if (message.contains(
      '콜백 URL',
    )) {
      return '카카오페이 성공·취소·실패 콜백 URL 설정을 확인해주세요.';
    }

    if (message.contains(
      'pgToken',
    ) ||
        message.contains(
          'pg_token',
        )) {
      return '카카오페이 승인 정보를 받지 못했습니다. '
          '결제 상태를 확인한 뒤 다시 시도해주세요.';
    }

    if (message.contains(
      '이미 다른 결제수단',
    )) {
      return '이 주문은 이미 다른 결제수단으로 시작되었습니다. '
          '현재 선택된 결제수단으로 다시 시도해주세요.';
    }

    return '주문 또는 결제를 완료하지 못했습니다.\n'
        '$message';
  }

  String _key(String prefix) {
    return '$prefix-'
        '${DateTime.now().microsecondsSinceEpoch}';
  }
}

class _PaymentProviderCard
    extends StatelessWidget {
  const _PaymentProviderCard({
    required this.provider,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final CustomerPaymentProvider provider;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final icon = switch (provider) {
      CustomerPaymentProvider
          .tossPayments =>
      Icons.credit_card_outlined,

      CustomerPaymentProvider
          .kakaoPay =>
      Icons.account_balance_wallet_outlined,
    };

    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 160,
      ),
      decoration: BoxDecoration(
        color:
        selected
            ? colorScheme
            .primaryContainer
            : colorScheme.surface,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          selected
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap:
        enabled ? onPressed : null,
        borderRadius:
        BorderRadius.circular(16),
        child: Padding(
          padding:
          const EdgeInsets.all(
            PopqSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color:
                selected
                    ? colorScheme.primary
                    : colorScheme
                    .onSurfaceVariant,
              ),
              const SizedBox(
                width: PopqSpacing.md,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.label,
                      style:
                      Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    const SizedBox(
                      height: PopqSpacing.xs,
                    ),
                    Text(
                      provider.description,
                      style:
                      Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              Icon(
                selected
                    ? Icons
                    .check_circle
                    : Icons
                    .radio_button_unchecked,
                color:
                selected
                    ? colorScheme.primary
                    : colorScheme
                    .outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentInformationBox
    extends StatelessWidget {
  const _PaymentInformationBox({
    required this.provider,
  });

  final CustomerPaymentProvider provider;

  @override
  Widget build(BuildContext context) {
    final message = switch (provider) {
      CustomerPaymentProvider
          .tossPayments =>
      '토스페이먼츠 테스트 결제창으로 진행됩니다. '
          '결제 인증 후 POPQ 서버에서 최종 승인을 처리합니다.',

      CustomerPaymentProvider
          .kakaoPay =>
      '카카오페이 테스트 결제창으로 진행됩니다. '
          '카카오페이 인증 후 POPQ 서버 승인이 완료되어야 '
          '주문이 정상 접수됩니다.',
    };

    return Container(
      padding:
      const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color:
        PopqPalette.lime.withValues(
          alpha: 0.35,
        ),
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Text(message),
    );
  }
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (
  var index = 0;
  index < digits.length;
  index++
  ) {
    if (index > 0 &&
        (digits.length - index) % 3 ==
            0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return '$buffer원';
}