import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../stores/seller_store_selection_controller.dart';
import 'seller_order_list_screen.dart';
import 'seller_order_repository.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  const SellerOrderDetailScreen({
    required this.orderPublicId,
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final String orderPublicId;
  final SellerOrderRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerOrderDetailScreen> createState() =>
      _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  SellerOrder? _order;
  Object? _error;
  var _loading = true;
  var _processing = false;

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
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '${sellerOrderTypeLabel(order.orderType)} · '
                  '${order.orderPublicId}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text('주문 상품', style: Theme.of(context).textTheme.titleLarge),
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
                        .map((option) => '${option.groupName}: ${option.name}')
                        .join(', '),
                ].join('\n'),
              ),
              trailing: Text(sellerWon(item.itemTotalPrice)),
            ),
          const Divider(),
          _AmountRow(label: '상품 금액', amount: order.subtotalAmount),
          if (order.discountAmount != 0)
            _AmountRow(label: '할인', amount: -order.discountAmount),
          if (order.taxAmount != 0)
            _AmountRow(label: '세금', amount: order.taxAmount),
          if (order.serviceFeeAmount != 0)
            _AmountRow(label: '서비스 수수료', amount: order.serviceFeeAmount),
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
          const SizedBox(height: PopqSpacing.lg),
          ..._actionButtons(order),
          OutlinedButton.icon(
            onPressed: _processing ? null : _sync,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('최신 상태 확인'),
          ),
          const SizedBox(height: PopqSpacing.sm),
          Text(
            '서버 버전 ${order.version} · 선택된 스토어 #${order.storeId} 전용 주문',
            textAlign: TextAlign.center,
          ),
        ],
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
              : () => _transition(SellerOrderCommand.accept),
          icon: const Icon(Icons.check_circle_outline_rounded),
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
              : () => _transition(SellerOrderCommand.prepare),
          icon: const Icon(Icons.soup_kitchen_outlined),
          label: const Text('준비 시작'),
        ),
      ],
      'PREPARING' => [
        FilledButton.icon(
          key: const Key('ready-order'),
          onPressed: _processing
              ? null
              : () => _transition(SellerOrderCommand.ready),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('준비 완료'),
        ),
      ],
      'READY' => [
        FilledButton.icon(
          key: const Key('complete-order'),
          onPressed: _processing
              ? null
              : () => _transition(SellerOrderCommand.complete),
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('주문 완료'),
        ),
      ],
      _ => <Widget>[],
    };
    if (actions.isEmpty) return actions;
    return [...actions, const SizedBox(height: PopqSpacing.sm)];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.repository.findOne(
        _storeId,
        widget.orderPublicId,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _sync() async {
    final current = _order;
    if (current == null || _processing) return;
    setState(() => _processing = true);
    try {
      final result = await widget.repository.sync(
        _storeId,
        current.orderPublicId,
        current.version,
      );
      if (!mounted) return;
      setState(() {
        if (result.order != null) _order = result.order;
        _processing = false;
      });
      _showMessage(
        result.refreshRequired ? '최신 주문 상태로 갱신했습니다.' : '이미 최신 상태입니다.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showMessage('최신 상태를 확인하지 못했습니다.');
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문 거절'),
        content: TextField(
          controller: controller,
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
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(context, value.isEmpty ? '판매자 주문 거절' : value);
            },
            child: const Text('거절 확정'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && mounted) {
      await _transition(SellerOrderCommand.reject, reason: reason);
    }
  }

  Future<void> _transition(SellerOrderCommand command, {String? reason}) async {
    final current = _order;
    if (current == null || _processing) return;
    setState(() => _processing = true);
    try {
      final updated = await widget.repository.transition(
        _storeId,
        current.orderPublicId,
        command,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _order = updated;
        _processing = false;
      });
      _showMessage('${sellerOrderStatusLabel(updated.status)} 상태로 변경했습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showMessage('주문 상태를 변경하지 못했습니다. 최신 상태를 확인해 주세요.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});

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
