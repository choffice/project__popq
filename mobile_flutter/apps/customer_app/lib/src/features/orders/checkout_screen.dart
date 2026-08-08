import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../cart/cart_controller.dart';
import '../discovery/store_discovery_repository.dart';
import 'customer_order_repository.dart';
import 'pending_payment_store.dart';
import 'pending_payment_recovery_service.dart';
import 'toss_payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.cartController,
    required this.orderRepository,
    required this.storeDiscoveryRepository,
    required this.tossClientKey,
    super.key,
  });

  final CartController cartController;
  final CustomerOrderRepository orderRepository;
  final StoreDiscoveryRepository storeDiscoveryRepository;
  final String tossClientKey;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final String _orderIdempotencyKey = _key('order');
  late String _paymentIdempotencyKey = _key('payment');

  final PendingPaymentStore _pendingPaymentStore = PendingPaymentStore();
  final TextEditingController _requestController = TextEditingController();

  late final PendingPaymentRecoveryService _pendingPaymentRecoveryService;
  Future<CustomerStore>? _storeFuture;

  CustomerOrder? _createdOrder;

  var _busy = false;
  var _agreedToPayment = false;
  String? _errorMessage;

  String? get _normalizedRequestMessage {
    final value = _requestController.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();

    _pendingPaymentRecoveryService = PendingPaymentRecoveryService(
      repository: widget.orderRepository,
      store: _pendingPaymentStore,
    );

    final storeId = widget.cartController.storeId;
    if (storeId != null) {
      _storeFuture = widget.storeDiscoveryRepository.findDetail(storeId);
    }
  }

  @override
  void dispose() {
    _requestController.dispose();
    super.dispose();
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

    final totalAmount = widget.cartController.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주문 확인'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          PopqSpacing.md,
          PopqSpacing.sm,
          PopqSpacing.md,
          PopqSpacing.xl,
        ),
        children: [
          _buildStoreCard(context),
          const SizedBox(height: PopqSpacing.md),
          _buildOrderItemsCard(context),
          const SizedBox(height: PopqSpacing.md),
          _buildRequestCard(context),
          const SizedBox(height: PopqSpacing.md),
          _buildPaymentSummaryCard(context),
          const SizedBox(height: PopqSpacing.md),
          _buildRefundGuideCard(context),
          const SizedBox(height: PopqSpacing.md),
          _buildConsentCard(context),
          if (_errorMessage != null) ...[
            const SizedBox(height: PopqSpacing.md),
            _buildErrorCard(context, _errorMessage!),
          ],
        ],
      ),
      bottomNavigationBar: _buildBottomPaymentBar(
        context,
        totalAmount,
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: FutureBuilder<CustomerStore>(
          future: _storeFuture,
          builder: (context, snapshot) {
            final store = snapshot.data;

            return Row(
              children: [
                _StoreImage(imageUrl: store?.imageUrl),
                const SizedBox(width: PopqSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store?.name ??
                            (snapshot.connectionState == ConnectionState.waiting
                                ? '매장 정보를 불러오는 중...'
                                : '매장 정보'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: PopqSpacing.sm),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: PopqPalette.lime.withValues(
                            alpha: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? 0.16
                                : 0.22,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: PopqPalette.lime.withValues(alpha: 0.55),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '포장 주문',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (snapshot.hasError) ...[
                        const SizedBox(height: PopqSpacing.xs),
                        Text(
                          '매장명은 주문 생성 후 다시 확인됩니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard(BuildContext context) {
    final items = widget.cartController.items;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_basket_outlined,
                  color: PopqPalette.forest,
                ),
                const SizedBox(width: PopqSpacing.sm),
                Expanded(
                  child: Text(
                    '주문 상품',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${widget.cartController.itemCount}개 상품',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: PopqSpacing.md),
            for (var index = 0; index < items.length; index++) ...[
              _OrderItemRow(item: items[index]),
              if (index != items.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: PopqSpacing.sm),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: PopqPalette.forest,
                ),
                const SizedBox(width: PopqSpacing.sm),
                Text(
                  '요청사항',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: PopqSpacing.md),
            TextField(
              controller: _requestController,
              enabled: _createdOrder == null && !_busy,
              maxLength: 100,
              maxLines: 3,
              minLines: 3,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '매장에 전달할 요청사항을 입력해주세요.',
                alignLabelWithHint: true,
              ),
            ),
            Text(
              '요청사항은 최대 100자까지 입력할 수 있어요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummaryCard(BuildContext context) {
    final totalAmount = widget.cartController.totalAmount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Column(
          children: [
            _SummaryRow(
              label: '상품 금액',
              value: _won(totalAmount),
            ),
            const SizedBox(height: PopqSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: PopqSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '총 결제금액',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  _won(totalAmount),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? PopqPalette.lime
                            : PopqPalette.forest,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundGuideCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PopqPalette.lime.withValues(
                  alpha: isDark ? 0.14 : 0.20,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: isDark ? PopqPalette.lime : PopqPalette.forest,
              ),
            ),
            const SizedBox(width: PopqSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '취소·환불 안내',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: PopqSpacing.xs),
                  Text(
                    '결제 후 주문 접수 여부와 진행 상태에 따라 '
                    '취소 및 환불 가능 범위가 달라질 수 있습니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: PopqSpacing.xs),
                  Text(
                    '현재 화면은 프로젝트 안내 범위이며, 실제 서비스 운영 시 '
                    '취소·환불 정책과 약관 문구는 별도 법률 검토 후 확정해야 합니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCard(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _busy
            ? null
            : () {
                setState(() {
                  _agreedToPayment = !_agreedToPayment;
                  _errorMessage = null;
                });
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PopqSpacing.sm,
            vertical: PopqSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: _agreedToPayment,
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() {
                          _agreedToPayment = value ?? false;
                          _errorMessage = null;
                        });
                      },
              ),
              Expanded(
                child: Text(
                  '주문 내용 및 취소·환불 안내를 확인했으며 '
                  '결제 진행에 동의합니다. (필수)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: PopqSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPaymentBar(
    BuildContext context,
    int totalAmount,
  ) {
    final canPay = !_busy && _agreedToPayment;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          PopqSpacing.md,
          PopqSpacing.sm,
          PopqSpacing.md,
          PopqSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(
                    alpha: 0.55,
                  ),
            ),
          ),
        ),
        child: FilledButton(
          onPressed: canPay ? _placeOrder : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
          ),
          child: Text(
            _busy
                ? '결제 상태를 확인하고 있어요...'
                : '${_won(totalAmount)} 결제하기',
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

    if (!_agreedToPayment) {
      setState(() {
        _errorMessage = '필수 안내 확인 및 결제 진행에 동의해주세요.';
      });
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

      final created =
          _createdOrder ??
          await widget.orderRepository.create(
            storeId: storeId,
            items: List.unmodifiable(widget.cartController.items),
            idempotencyKey: _orderIdempotencyKey,
            requestMessage: _normalizedRequestMessage,
          );

      _createdOrder = created;

      final canStartNewPayment = await _resolvePendingBeforeNewPayment(
        created,
      );

      if (!canStartNewPayment || !mounted) {
        return;
      }

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

      if (tossResult == null) {
        setState(() {
          _busy = false;
          _errorMessage = '결제가 취소되었습니다.';
        });
        return;
      }

      if (!tossResult.success) {
        setState(() {
          _busy = false;
          _errorMessage =
              tossResult.errorMessage ?? '결제 인증에 실패했습니다.';
        });
        return;
      }

      final paymentKey = tossResult.paymentKey;

      if (paymentKey == null || paymentKey.isEmpty) {
        throw StateError('토스페이먼츠 paymentKey가 없습니다.');
      }

      final pending = PendingPayment(
        orderPublicId: created.orderPublicId,
        paymentKey: paymentKey,
        idempotencyKey: _paymentIdempotencyKey,
        amount: created.totalAmount,
        savedAt: DateTime.now(),
      );

      await _pendingPaymentStore.save(pending);

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

    if (pending.orderPublicId == created.orderPublicId) {
      if (pending.amount != created.totalAmount) {
        throw StateError(
          '저장된 결제 금액과 현재 주문 금액이 다릅니다. '
          '새 결제를 진행하지 않고 결제 내역을 확인해주세요.',
        );
      }

      _paymentIdempotencyKey = pending.idempotencyKey;
    }

    final outcome = await _pendingPaymentRecoveryService.recover();

    switch (outcome.kind) {
      case PendingPaymentRecoveryKind.none:
        return true;

      case PendingPaymentRecoveryKind.paid:
        if (outcome.orderPublicId != null) {
          await _finishRecoveredOrder(
            outcome.orderPublicId!,
            clearCart: outcome.orderPublicId == created.orderPublicId,
          );
        }
        return false;

      case PendingPaymentRecoveryKind.retryAllowed:
        _paymentIdempotencyKey = _key('payment');
        return true;

      case PendingPaymentRecoveryKind.pending:
        throw StateError(
          outcome.message ??
              '이전 결제 승인 결과를 확인하고 있습니다. '
                  '새 결제를 진행하지 않고 잠시 후 다시 확인해주세요.',
        );

      case PendingPaymentRecoveryKind.manualReview:
      case PendingPaymentRecoveryKind.inconsistent:
        throw StateError(
          outcome.message ??
              '결제 상태를 자동으로 확정할 수 없습니다. '
                  '새 결제를 진행하지 말고 주문 내역을 확인해주세요.',
        );

      case PendingPaymentRecoveryKind.unavailable:
        throw StateError(
          outcome.message ??
              '결제 상태를 확인하지 못했습니다. '
                  '네트워크 연결 후 다시 시도해주세요.',
        );
    }
  }

  Future<bool> _tryRecoverPendingPayment(
    PendingPayment pending, {
    bool navigateWhenPaid = true,
  }) async {
    try {
      final outcome = await _pendingPaymentRecoveryService.recover();

      if (outcome.orderPublicId != null &&
          outcome.orderPublicId != pending.orderPublicId) {
        throw StateError(
          '복구된 주문 번호가 저장된 결제 정보와 일치하지 않습니다.',
        );
      }

      switch (outcome.kind) {
        case PendingPaymentRecoveryKind.none:
          return false;

        case PendingPaymentRecoveryKind.paid:
          if (navigateWhenPaid && outcome.orderPublicId != null) {
            await _finishRecoveredOrder(outcome.orderPublicId!);
          }
          return true;

        case PendingPaymentRecoveryKind.retryAllowed:
          _paymentIdempotencyKey = _key('payment');

          if (mounted) {
            setState(() {
              _busy = false;
              _errorMessage =
                  outcome.message ?? '결제 승인이 실패했습니다. 다시 결제해주세요.';
            });
          }

          return true;

        case PendingPaymentRecoveryKind.pending:
        case PendingPaymentRecoveryKind.manualReview:
        case PendingPaymentRecoveryKind.inconsistent:
        case PendingPaymentRecoveryKind.unavailable:
          if (mounted) {
            setState(() {
              _busy = false;
              _errorMessage =
                  outcome.message ??
                  '결제 결과를 아직 확정하지 못했습니다. '
                      '새 결제를 진행하지 말고 다시 확인해주세요.';
            });
          }

          return true;
      }
    } catch (error, stackTrace) {
      debugPrint('결제 복구 확인 오류: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _finishRecoveredOrder(
    String orderPublicId, {
    bool clearCart = true,
  }) async {
    if (clearCart) {
      widget.cartController.clear();
    }

    if (!mounted) {
      return;
    }

    context.go('${CustomerRoutes.orders}/$orderPublicId');
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
      return '결제 인증 정보가 올바르지 않습니다. 다시 시도해주세요.';
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
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final optionText = item.options.map((option) => option.name).join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProductImage(imageUrl: item.product.imageUrl),
        const SizedBox(width: PopqSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (optionText.isNotEmpty) ...[
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  optionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: PopqSpacing.sm),
        Text(
          '${item.quantity}개',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(width: PopqSpacing.md),
        SizedBox(
          width: 84,
          child: Text(
            _won(item.totalPrice),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _StoreImage extends StatelessWidget {
  const _StoreImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = this.imageUrl?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        height: 72,
        child: imageUrl == null || imageUrl.isEmpty
            ? const _ImageFallback(icon: Icons.storefront_outlined)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const _ImageFallback(
                    icon: Icons.storefront_outlined,
                  );
                },
              ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = this.imageUrl?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 64,
        child: imageUrl == null || imageUrl.isEmpty
            ? const _ImageFallback(icon: Icons.fastfood_outlined)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const _ImageFallback(icon: Icons.fastfood_outlined);
                },
              ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: isDark ? PopqPalette.nightElevated : PopqPalette.mist,
      child: Center(
        child: Icon(
          icon,
          color: isDark
              ? PopqPalette.nightMutedText
              : PopqPalette.lightMutedText,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
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
