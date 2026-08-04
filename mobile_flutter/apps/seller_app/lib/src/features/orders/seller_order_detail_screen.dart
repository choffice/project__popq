import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../stores/seller_store_selection_controller.dart';
import '../stores/seller_store_repository.dart';
import 'seller_order_list_screen.dart';
import 'seller_order_repository.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  const SellerOrderDetailScreen({
    required this.orderPublicId,
    required this.repository,
    required this.storeRepository,
    required this.selectionController,
    super.key,
  });

  final String orderPublicId;
  final SellerOrderRepository repository;
  final SellerStoreRepository storeRepository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerOrderDetailScreen> createState() =>
      _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  SellerOrder? _order;
  SellerPaymentSummary? _payment;
  Object? _paymentError;
  Object? _error;
  var _loading = true;
  var _processing = false;
  var _paymentLoading = false;
  var _canRefund = false;

  int get _storeId {
    final storeId = widget.selectionController.selectedStoreId;
    if (storeId == null) throw StateError('selected store is missing');
    return storeId;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('판매자 주문 상세')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(message: '최신 주문 상태를 확인하고 있어요.');
    }

    if (_error != null || _order == null) {
      return PopqErrorView(
        message: '선택한 스토어의 주문 상세를 불러오지 못했습니다.',
        onRetry: _load,
      );
    }

    final order = _order!;

    return RefreshIndicator(
      onRefresh: _sync,
      child: ListView(
        key: const Key('order-detail-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PopqSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            decoration: BoxDecoration(
              color: PopqPalette.ink,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: sellerOrderStatusColor(order.status),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: PopqPalette.ink,
                    size: 30,
                  ),
                ),
                const SizedBox(height: PopqSpacing.sm),
                Text(
                  sellerOrderStatusLabel(order.status),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '${sellerOrderTypeLabel(order.orderType)} · '
                      '${formatPopqOrderNumber(order.orderPublicId)}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text(
            '주문 상품',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: PopqSpacing.sm),
          for (final item in order.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.productName),
              subtitle: Text(
                [
                  '${item.quantity}개 · 단가 ${sellerWon(item.unitPrice)}',
                  if (item.options.isNotEmpty)
                    item.options
                        .map(
                          (option) =>
                      '${option.groupName}: ${option.name}',
                    )
                        .join(', '),
                ].join('\n'),
              ),
              trailing: Text(sellerWon(item.itemTotalPrice)),
            ),
          const Divider(),
          _AmountRow(
            label: '상품 금액',
            amount: order.subtotalAmount,
          ),
          if (order.discountAmount != 0)
            _AmountRow(
              label: '할인',
              amount: -order.discountAmount,
            ),
          if (order.taxAmount != 0)
            _AmountRow(
              label: '세금',
              amount: order.taxAmount,
            ),
          if (order.serviceFeeAmount != 0)
            _AmountRow(
              label: '서비스 수수료',
              amount: order.serviceFeeAmount,
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '총 결제 금액',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: Text(
              sellerWon(order.totalAmount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (order.status == 'COMPLETED') ...[
            const SizedBox(height: PopqSpacing.lg),
            _paymentSection(order),
          ],
          const SizedBox(height: PopqSpacing.lg),
          ..._actionButtons(order),
          OutlinedButton.icon(
            onPressed: _processing ? null : _sync,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('최신 상태 확인'),
          ),
          const SizedBox(height: PopqSpacing.sm),
          Text(
            '서버 버전 ${order.version} · '
                '선택된 스토어 #${order.storeId} 전용 주문',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _paymentSection(SellerOrder order) {
    if (_paymentLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(PopqSpacing.lg),
          child: Column(
            children: [
              LinearProgressIndicator(),
              SizedBox(height: PopqSpacing.sm),
              Text('결제·환불 정보를 확인하고 있어요.'),
            ],
          ),
        ),
      );
    }

    if (_paymentError != null || _payment == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.lg),
          child: Column(
            children: [
              const Text('결제·환불 정보를 불러오지 못했습니다.'),
              TextButton(
                key: const Key('retry-payment'),
                onPressed: _processing ? null : _loadPayment,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final payment = _payment!;

    final canRequestRefund =
        _canRefund &&
            payment.paymentStatus == 'PAID' &&
            payment.refundableAmount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '결제·환불',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(
                    _paymentStatusLabel(payment.paymentStatus),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PopqSpacing.sm),
            _PaymentRow(
              label: '결제 수단',
              value: payment.paymentMethod,
            ),
            _PaymentRow(
              label: '승인 금액',
              value: sellerWon(payment.approvedAmount),
            ),
            _PaymentRow(
              label: '환불 금액',
              value: sellerWon(payment.refundedAmount),
            ),
            _PaymentRow(
              label: '환불 가능 금액',
              value: sellerWon(payment.refundableAmount),
            ),
            if (payment.refunds.isNotEmpty) ...[
              const Divider(),
              const Text(
                '환불 이력',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: PopqSpacing.xs),
              for (final refund in payment.refunds)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    refund.status == 'SUCCEEDED'
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                  ),
                  title: Text(refund.reason),
                  subtitle: Text(
                    '${_refundRequesterLabel(refund.requesterType)} · '
                        '${_refundStatusLabel(refund.status)}',
                  ),
                  trailing: Text(sellerWon(refund.amount)),
                ),
            ],
            if (canRequestRefund) ...[
              const SizedBox(height: PopqSpacing.sm),
              FilledButton.icon(
                key: const Key('refund-order'),
                onPressed: _processing
                    ? null
                    : () => _refund(order),
                icon: const Icon(
                  Icons.currency_exchange_rounded,
                ),
                label: Text(
                  '${sellerWon(payment.refundableAmount)} 전액 환불',
                ),
              ),
            ] else if (!_canRefund &&
                payment.refundableAmount > 0) ...[
              const SizedBox(height: PopqSpacing.sm),
              const Text(
                '환불은 사업장 OWNER 또는 MANAGER만 처리할 수 있습니다.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _actionButtons(SellerOrder order) {
    final actions = switch (order.status) {
      'PLACED' => [
        FilledButton.icon(
          key: const Key('accept-order'),
          onPressed: _processing
              ? null
              : () => _transition(
            SellerOrderCommand.accept,
          ),
          icon: const Icon(
            Icons.check_circle_outline_rounded,
          ),
          label: const Text('주문 접수'),
        ),
        const SizedBox(height: PopqSpacing.sm),
        OutlinedButton.icon(
          key: const Key('reject-order'),
          onPressed: _processing ? null : _reject,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('주문 거절'),
        ),
      ],
      'ACCEPTED' => [
        FilledButton.icon(
          key: const Key('prepare-order'),
          onPressed: _processing
              ? null
              : () => _transition(
            SellerOrderCommand.prepare,
          ),
          icon: const Icon(Icons.soup_kitchen_outlined),
          label: const Text('준비 시작'),
        ),
      ],
      'PREPARING' => [
        FilledButton.icon(
          key: const Key('ready-order'),
          onPressed: _processing
              ? null
              : () => _transition(
            SellerOrderCommand.ready,
          ),
          icon: const Icon(
            Icons.notifications_active_outlined,
          ),
          label: const Text('준비 완료'),
        ),
      ],
      'READY' => [
        FilledButton.icon(
          key: const Key('complete-order'),
          onPressed: _processing
              ? null
              : () => _transition(
            SellerOrderCommand.complete,
          ),
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('주문 완료'),
        ),
      ],
      _ => <Widget>[],
    };

    if (actions.isEmpty) {
      return actions;
    }

    return [
      ...actions,
      const SizedBox(height: PopqSpacing.sm),
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await Future.wait([
        widget.repository.findOne(
          _storeId,
          widget.orderPublicId,
        ),
        widget.storeRepository.findOne(_storeId),
      ]);

      final order = result[0] as SellerOrder;
      final store = result[1] as SellerStore;

      if (!mounted) {
        return;
      }

      setState(() {
        _order = order;
        _canRefund =
            store.myRole == 'OWNER' ||
                store.myRole == 'MANAGER';
        _loading = false;
      });

      if (order.status == 'COMPLETED') {
        await _loadPayment();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _sync() async {
    final current = _order;

    if (current == null || _processing) {
      return;
    }

    setState(() => _processing = true);

    try {
      final result = await widget.repository.sync(
        _storeId,
        current.orderPublicId,
        current.version,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (result.order != null) {
          _order = result.order;
        }

        _processing = false;
      });

      _showMessage(
        result.refreshRequired
            ? '최신 주문 상태로 갱신했습니다.'
            : '이미 최신 상태입니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _processing = false);

      _showMessage('최신 상태를 확인하지 못했습니다.');
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );

    if (reason == null || !mounted) {
      return;
    }

    await _transition(
      SellerOrderCommand.reject,
      reason: reason,
    );
  }

  Future<void> _transition(
      SellerOrderCommand command, {
        String? reason,
      }) async {
    final current = _order;

    if (current == null || _processing) {
      return;
    }

    setState(() => _processing = true);

    try {
      final updated = await widget.repository.transition(
        _storeId,
        current.orderPublicId,
        command,
        reason: reason,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _order = updated;
        _processing = false;
      });

      _showMessage(
        '${sellerOrderStatusLabel(updated.status)} 상태로 변경했습니다.',
      );

      if (updated.status == 'COMPLETED') {
        await _loadPayment();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _processing = false);

      _showMessage(
        '주문 상태를 변경하지 못했습니다. 최신 상태를 확인해 주세요.',
      );
    }
  }

  Future<void> _loadPayment() async {
    final order = _order;

    if (order == null || order.status != 'COMPLETED') {
      return;
    }

    setState(() {
      _paymentLoading = true;
      _paymentError = null;
    });

    try {
      final payment = await widget.repository.findPayment(
        _storeId,
        order.orderPublicId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payment = payment;
        _paymentLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _paymentError = error;
        _paymentLoading = false;
      });
    }
  }

  Future<void> _refund(SellerOrder order) async {
    final payment = _payment;

    if (payment == null ||
        payment.refundableAmount <= 0 ||
        _processing) {
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RefundDialog(
        amount: payment.refundableAmount,
      ),
    );

    if (reason == null || !mounted) {
      return;
    }

    setState(() => _processing = true);

    try {
      final updated = await widget.repository.refund(
        _storeId,
        order.orderPublicId,
        amount: payment.refundableAmount,
        reason: reason,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payment = updated;
        _processing = false;
      });

      _showMessage('전액 환불을 완료했습니다.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _processing = false);

      _showMessage('환불을 처리하지 못했습니다.');
    }
  }

  String _paymentStatusLabel(String status) {
    return switch (status) {
      'PAID' => '결제 완료',
      'REFUNDED' => '환불 완료',
      'CANCELED' => '결제 취소',
      'PARTIALLY_REFUNDED' => '부분 환불',
      'FAILED' => '결제 실패',
      _ => '결제 확인 중',
    };
  }

  String _refundStatusLabel(String status) {
    return switch (status) {
      'SUCCEEDED' => '환불 완료',
      'FAILED' => '환불 실패',
      'PROCESSING' => '처리 중',
      _ => '요청됨',
    };
  }

  String _refundRequesterLabel(String requester) {
    return switch (requester) {
      'SELLER' => '판매자 요청',
      'ADMIN' => '관리자 요청',
      'CUSTOMER' => '고객 요청',
      _ => '비회원 요청',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
  });

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(sellerWon(amount)),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() =>
      _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _controller =
  TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('주문 거절'),
      content: TextField(
        key: const Key('reject-reason'),
        controller: _controller,
        maxLength: 500,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '거절 사유',
          hintText: '예: 재료가 소진되었습니다.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-reject'),
          onPressed: () {
            final value = _controller.text.trim();

            Navigator.pop(
              context,
              value.isEmpty
                  ? '판매자 주문 거절'
                  : value,
            );
          },
          child: const Text('거절 확정'),
        ),
      ],
    );
  }
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({
    required this.amount,
  });

  final int amount;

  @override
  State<_RefundDialog> createState() =>
      _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final TextEditingController _controller =
  TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('전액 환불 확인'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${sellerWon(widget.amount)} 전액을 환불합니다.',
            ),
            const SizedBox(height: PopqSpacing.sm),
            TextField(
              key: const Key('refund-reason'),
              controller: _controller,
              autofocus: true,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '환불 사유',
                hintText: '고객에게 안내할 환불 사유',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-refund'),
          onPressed: () {
            final value = _controller.text.trim();

            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
          child: const Text('전액 환불 확정'),
        ),
      ],
    );
  }
}