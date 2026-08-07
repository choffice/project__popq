import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import 'customer_order_repository.dart';
import 'customer_payment_provider.dart';
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
  static final Uri _financialTermsUri = Uri.parse(
    'https://pages.tosspayments.com/terms/user/',
  );

  static final Uri _privacyCollectionUri = Uri.parse(
    'https://pages.tosspayments.com/terms/privacy/consent1',
  );

  static final Uri _privacyProvisionUri = Uri.parse(
    'https://pages.tosspayments.com/terms/privacy/consent2',
  );

  late final String _orderIdempotencyKey = _key('order');
  late final String _paymentIdempotencyKey = _key('toss-payment');

  CustomerPaymentProvider _selectedProvider =
      CustomerPaymentProvider.tossPayments;

  CustomerPaymentProvider? _startedProvider;
  CustomerOrder? _createdOrder;

  bool _directTermsAgreed = false;
  bool _busy = false;
  String? _errorMessage;

  bool get _paymentProviderLocked => _startedProvider != null;

  bool get _requiresDirectTermsConsent {
    return _selectedProvider.requiresDirectTermsConsent;
  }

  bool get _canSubmit {
    if (_busy) {
      return false;
    }

    if (_requiresDirectTermsConsent && !_directTermsAgreed) {
      return false;
    }

    return true;
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
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: [
          Text(
            '포장 주문',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
          const SizedBox(height: PopqSpacing.lg),
          Text(
            '결제수단',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PopqSpacing.sm),
          for (final provider in CustomerPaymentProvider.values) ...[
            _PaymentProviderCard(
              provider: provider,
              selected: _selectedProvider == provider,
              enabled: !_busy && !_paymentProviderLocked,
              onPressed: () => _selectProvider(provider),
            ),
            if (provider != CustomerPaymentProvider.values.last)
              const SizedBox(height: PopqSpacing.sm),
          ],
          if (_paymentProviderLocked) ...[
            const SizedBox(height: PopqSpacing.sm),
            Text(
              '${_startedProvider!.label} 결제가 이미 시작되었습니다. '
              '재시도할 때도 같은 결제수단을 사용합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: PopqSpacing.md),
          _PaymentInformationBox(
            provider: _selectedProvider,
          ),
          if (_requiresDirectTermsConsent) ...[
            const SizedBox(height: PopqSpacing.md),
            _DirectPaymentTerms(
              agreed: _directTermsAgreed,
              enabled: !_busy,
              onChanged: (value) {
                setState(() {
                  _directTermsAgreed = value;
                  _errorMessage = null;
                });
              },
              onOpenFinancialTerms: () => _openTerms(_financialTermsUri),
              onOpenPrivacyCollection: () =>
                  _openTerms(_privacyCollectionUri),
              onOpenPrivacyProvision: () =>
                  _openTerms(_privacyProvisionUri),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: PopqSpacing.md),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: PopqPalette.coral,
              ),
            ),
          ],
          const SizedBox(height: PopqSpacing.lg),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: FilledButton(
            onPressed: _canSubmit ? _placeOrder : null,
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

  void _selectProvider(CustomerPaymentProvider provider) {
    if (_busy ||
        _paymentProviderLocked ||
        provider == _selectedProvider) {
      return;
    }

    setState(() {
      _selectedProvider = provider;
      _directTermsAgreed = false;
      _errorMessage = null;
    });
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
      _validateSelectedProvider();

      final order =
          _createdOrder ??
          await widget.orderRepository.create(
            storeId: storeId,
            items: List.unmodifiable(widget.cartController.items),
            idempotencyKey: _orderIdempotencyKey,
          );

      _createdOrder = order;

      if (!mounted) {
        return;
      }

      setState(() {
        _startedProvider ??= _selectedProvider;
      });

      final paid = await _payWithToss(order);

      if (paid == null || !mounted) {
        return;
      }

      widget.cartController.clear();

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

  void _validateSelectedProvider() {
    if (_startedProvider != null && _startedProvider != _selectedProvider) {
      throw StateError('이미 다른 결제수단으로 결제가 시작되었습니다.');
    }

    if (_selectedProvider.requiresTossClientKey &&
        widget.tossClientKey.trim().isEmpty) {
      throw StateError('토스페이먼츠 클라이언트 키가 설정되지 않았습니다.');
    }

    if (_requiresDirectTermsConsent && !_directTermsAgreed) {
      throw StateError('네이버페이 결제를 위한 필수 약관에 동의해주세요.');
    }
  }

  Future<CustomerOrder?> _payWithToss(CustomerOrder order) async {
    final flow = _selectedProvider.usesNaverPayDirect
        ? TossPaymentFlow.naverPayDirect
        : TossPaymentFlow.integrated;

    final result = await Navigator.of(context).push<TossPaymentResult>(
      MaterialPageRoute(
        builder: (_) => TossPaymentScreen(
          clientKey: widget.tossClientKey,
          orderId: order.orderPublicId,
          orderName: _buildOrderName(order),
          amount: order.totalAmount,
          flow: flow,
        ),
      ),
    );

    if (!mounted) {
      return null;
    }

    if (result == null) {
      _stopPayment(
        '${_selectedProvider.label} 결제 화면을 닫았습니다. '
        '같은 결제수단으로 다시 시도할 수 있습니다.',
      );
      return null;
    }

    if (!result.success) {
      _stopPayment(
        result.errorMessage ?? '${_selectedProvider.label} 결제 인증에 실패했습니다.',
      );
      return null;
    }

    if (result.orderId != order.orderPublicId) {
      throw StateError('결제 주문번호가 현재 주문과 일치하지 않습니다.');
    }

    if (result.amount != order.totalAmount) {
      throw StateError('결제 금액이 현재 주문 금액과 일치하지 않습니다.');
    }

    final paymentKey = result.paymentKey;

    if (paymentKey == null || paymentKey.trim().isEmpty) {
      throw StateError('토스페이먼츠 paymentKey가 없습니다.');
    }

    return widget.orderRepository.confirmPayment(
      order,
      idempotencyKey: _paymentIdempotencyKey,
      paymentKey: paymentKey,
    );
  }

  Future<void> _openTerms(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw StateError('약관 페이지를 열지 못했습니다.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '약관 페이지를 열지 못했습니다.\n$error';
      });
    }
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

    if (message.contains('클라이언트 키')) {
      return '토스페이먼츠 클라이언트 키가 설정되지 않았습니다. '
          '고객 앱 실행 설정을 확인해주세요.';
    }

    if (message.contains('필수 약관')) {
      return '네이버페이 결제를 진행하려면 필수 약관에 동의해주세요.';
    }

    if (message.contains('paymentKey')) {
      return '토스페이먼츠 결제 인증 정보가 올바르지 않습니다. '
          '다시 시도해주세요.';
    }

    if (message.contains('이미 다른 결제수단')) {
      return '이 주문은 이미 다른 결제수단으로 시작되었습니다. '
          '현재 선택된 결제수단으로 다시 시도해주세요.';
    }

    return '주문 또는 결제를 완료하지 못했습니다.\n$message';
  }

  String _key(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}

class _PaymentProviderCard extends StatelessWidget {
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
    final colorScheme = Theme.of(context).colorScheme;

    final icon = switch (provider) {
      CustomerPaymentProvider.tossPayments => Icons.credit_card_outlined,
      CustomerPaymentProvider.naverPay => Icons.account_balance_wallet_outlined,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: PopqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: PopqSpacing.xs),
                    Text(
                      provider.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PopqSpacing.sm),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentInformationBox extends StatelessWidget {
  const _PaymentInformationBox({
    required this.provider,
  });

  final CustomerPaymentProvider provider;

  @override
  Widget build(BuildContext context) {
    final message = switch (provider) {
      CustomerPaymentProvider.tossPayments =>
        '토스페이먼츠 통합 결제창에서 카드, 토스페이, 카카오페이, '
            '네이버페이 등 사용할 결제수단을 선택합니다.',
      CustomerPaymentProvider.naverPay =>
        '토스페이먼츠가 네이버페이 결제창을 바로 실행합니다. '
            '승인과 취소·환불은 기존 토스페이먼츠 흐름을 그대로 사용합니다.',
    };

    return Container(
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: PopqPalette.lime.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message),
    );
  }
}

class _DirectPaymentTerms extends StatelessWidget {
  const _DirectPaymentTerms({
    required this.agreed,
    required this.enabled,
    required this.onChanged,
    required this.onOpenFinancialTerms,
    required this.onOpenPrivacyCollection,
    required this.onOpenPrivacyProvision,
  });

  final bool agreed;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenFinancialTerms;
  final VoidCallback onOpenPrivacyCollection;
  final VoidCallback onOpenPrivacyProvision;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: agreed,
            onChanged: enabled
                ? (value) => onChanged(value ?? false)
                : null,
            title: const Text('네이버페이 결제 필수 약관에 모두 동의합니다.'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(PopqSpacing.sm),
            child: Wrap(
              spacing: PopqSpacing.xs,
              runSpacing: PopqSpacing.xs,
              children: [
                TextButton(
                  onPressed: onOpenFinancialTerms,
                  child: const Text('전자금융거래 약관'),
                ),
                TextButton(
                  onPressed: onOpenPrivacyCollection,
                  child: const Text('개인정보 수집·이용'),
                ),
                TextButton(
                  onPressed: onOpenPrivacyProvision,
                  child: const Text('개인정보 제3자 제공'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
