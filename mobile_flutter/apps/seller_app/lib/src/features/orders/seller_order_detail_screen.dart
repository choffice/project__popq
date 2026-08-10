import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/seller_realtime_scope.dart';
import '../stores/seller_store_selection_controller.dart';
import '../stores/seller_store_repository.dart';
import 'seller_order_list_screen.dart';
import 'seller_order_repository.dart';
import '../reviews/seller_review_repository.dart';

class SellerOrderDetailScreen extends StatefulWidget {
  const SellerOrderDetailScreen({
    required this.orderPublicId,
    required this.repository,
    required this.storeRepository,
    required this.selectionController,
    required this.reviewRepository,
    this.storeId,
    super.key,
  });

  final String orderPublicId;
  final SellerOrderRepository repository;
  final SellerStoreRepository storeRepository;
  final SellerStoreSelectionController selectionController;
  final SellerReviewRepository reviewRepository;
  final int? storeId;

  @override
  State<SellerOrderDetailScreen> createState() =>
      _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen>
    with WidgetsBindingObserver {
  static const Duration _pollingInterval = Duration(seconds: 3);
  SellerOrder? _order;
  SellerPaymentSummary? _payment;
  SellerReview? _review;
  Object? _paymentError;
  Object? _error;
  var _loading = true;
  var _processing = false;
  var _paymentLoading = false;
  var _canRefund = false;
  var _defaultPreparationMinutes = 10;
  var _lastConnectionEpoch = 0;
  var _isAppActive = true;

  Timer? _pollingTimer;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _orderSubscription;

  int get _storeId {
    final storeId =
        widget.storeId ?? widget.selectionController.selectedStoreId;
    if (storeId == null) throw StateError('selected store is missing');
    return storeId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    unawaited(_load());
    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextRealtimeClient = SellerRealtimeScope.maybeOf(context);
    if (identical(_realtimeClient, nextRealtimeClient)) {
      return;
    }

    _realtimeClient?.removeListener(_handleRealtimeClientChanged);
    _orderSubscription?.cancel();
    _orderSubscription = null;

    _realtimeClient = nextRealtimeClient;
    _lastConnectionEpoch = nextRealtimeClient?.connectionEpoch ?? 0;
    nextRealtimeClient?.addListener(_handleRealtimeClientChanged);

    _subscribeToOrder();
    _updatePollingForConnection();
  }

  @override
  void didUpdateWidget(covariant SellerOrderDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.orderPublicId != widget.orderPublicId ||
        oldWidget.storeId != widget.storeId ||
        oldWidget.repository != widget.repository ||
        oldWidget.selectionController != widget.selectionController) {
      _orderSubscription?.cancel();
      _orderSubscription = null;
      _order = null;
      _payment = null;
      _review = null;
      _error = null;
      _subscribeToOrder();
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _subscribeToOrder();
        _updatePollingForConnection();
        unawaited(_syncSilently());
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isAppActive = false;
        _stopPolling();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('?먮ℓ??二쇰Ц ?곸꽭')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(message: '理쒖떊 二쇰Ц ?곹깭瑜??뺤씤?섍퀬 ?덉뼱??');
    }

    if (_error != null || _order == null) {
      return PopqErrorView(
        message: '?좏깮???ㅽ넗?댁쓽 二쇰Ц ?곸꽭瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲??',
        onRetry: _load,
      );
    }

    final order = _order!;
    final requestMessage = order.requestMessage;
    final terminalHistory = _terminalStatusHistory(order);

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
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: sellerOrderStatusForegroundColor(order.status),
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
                  '${sellerOrderTypeLabel(order.orderType)} 쨌 '
                  '${formatPopqOrderNumber(order.orderPublicId)}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: PopqSpacing.lg),
          Text('二쇰Ц ?곹뭹', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PopqSpacing.sm),
          for (final item in order.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.productName),
              subtitle: Text(
                [
                  '${item.quantity}媛?쨌 ?④? ${sellerWon(item.unitPrice)}',
                  if (item.options.isNotEmpty)
                    item.options
                        .map((option) => '${option.groupName}: ${option.name}')
                        .join(', '),
                ].join('\n'),
              ),
              trailing: Text(sellerWon(item.itemTotalPrice)),
            ),
          const SizedBox(height: PopqSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(PopqSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: PopqSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '?붿껌?ы빆',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: PopqSpacing.xs),
                        Text(
                          requestMessage ?? '?붿껌?ы빆 ?놁쓬',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: requestMessage == null
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (terminalHistory != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _cancellationSection(order, terminalHistory),
          ],
          const SizedBox(height: PopqSpacing.sm),
          const Divider(),
          _AmountRow(label: '?곹뭹 湲덉븸', amount: order.subtotalAmount),
          if (order.discountAmount != 0)
            _AmountRow(label: '?좎씤', amount: -order.discountAmount),
          if (order.taxAmount != 0)
            _AmountRow(label: '?멸툑', amount: order.taxAmount),
          if (order.serviceFeeAmount != 0)
            _AmountRow(label: '?쒕퉬???섏닔猷?, amount: order.serviceFeeAmount),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '珥?寃곗젣 湲덉븸',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: Text(
              sellerWon(order.totalAmount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (order.preparationMinutes != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined),
              title: Text(
                order.preparationMinutes == 0
                    ? '以鍮?利됱떆 ?쒖옉'
                    : '以鍮꾩떆媛?${order.preparationMinutes}遺?,
              ),
              subtitle: order.estimatedReadyAt == null
                  ? null
                  : Text('?덉긽 ?꾨즺 ${_formatDateTime(order.estimatedReadyAt!)}'),
            ),
          ],
          if (_shouldLoadPayment(order)) ...[
            const SizedBox(height: PopqSpacing.lg),
            _paymentSection(order),
          ],
          if (order.status == 'COMPLETED') ...[
            const SizedBox(height: PopqSpacing.lg),
            _reviewSection(),
          ],
          const SizedBox(height: PopqSpacing.lg),
          ..._actionButtons(order),
          OutlinedButton.icon(
            onPressed: _processing ? null : _sync,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('理쒖떊 ?곹깭 ?뺤씤'),
          ),
          const SizedBox(height: PopqSpacing.sm),
          Text(
            '?쒕쾭 踰꾩쟾 ${order.version} 쨌 '
            '?좏깮???ㅽ넗??#${order.storeId} ?꾩슜 二쇰Ц',
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
              Text('寃곗젣쨌?섎텋 ?뺣낫瑜??뺤씤?섍퀬 ?덉뼱??'),
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
              const Text('寃곗젣쨌?섎텋 ?뺣낫瑜?遺덈윭?ㅼ? 紐삵뻽?듬땲??'),
              TextButton(
                key: const Key('retry-payment'),
                onPressed: _processing ? null : _loadPayment,
                child: const Text('?ㅼ떆 ?쒕룄'),
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
                    '寃곗젣쨌?섎텋',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(_paymentStatusLabel(payment.paymentStatus))),
              ],
            ),
            const SizedBox(height: PopqSpacing.sm),
            _PaymentRow(label: '寃곗젣 ?섎떒', value: payment.paymentMethod),
            _PaymentRow(
              label: '?뱀씤 湲덉븸',
              value: sellerWon(payment.approvedAmount),
            ),
            _PaymentRow(
              label: '?섎텋 湲덉븸',
              value: sellerWon(payment.refundedAmount),
            ),
            _PaymentRow(
              label: '?섎텋 媛??湲덉븸',
              value: sellerWon(payment.refundableAmount),
            ),
            if (payment.refunds.isNotEmpty) ...[
              const Divider(),
              const Text(
                '?섎텋 ?대젰',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: PopqSpacing.xs),
              for (var index = 0; index < payment.refunds.length; index++)
                _refundHistoryCard(
                  payment.refunds[index],
                  index + 1,
                ),
            ],
            if (canRequestRefund) ...[
              const SizedBox(height: PopqSpacing.sm),
              FilledButton.icon(
                key: const Key('refund-order'),
                onPressed: _processing ? null : () => _refund(order),
                icon: const Icon(Icons.currency_exchange_rounded),
                label: Text('${sellerWon(payment.refundableAmount)} ?꾩븸 ?섎텋'),
              ),
            ] else if (!_canRefund && payment.refundableAmount > 0) ...[
              const SizedBox(height: PopqSpacing.sm),
              const Text(
                '?섎텋? ?ъ뾽??OWNER ?먮뒗 MANAGER留?泥섎━?????덉뒿?덈떎.',
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
          onPressed: _processing ? null : _accept,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('二쇰Ц ?묒닔'),
        ),
        const SizedBox(height: PopqSpacing.sm),
        OutlinedButton.icon(
          key: const Key('reject-order'),
          onPressed: _processing ? null : _reject,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('二쇰Ц 嫄곗젅'),
        ),
      ],
      'ACCEPTED' => [
        FilledButton.icon(
          key: const Key('prepare-order'),
          onPressed: _processing
              ? null
              : () => _transition(SellerOrderCommand.prepare),
          icon: const Icon(Icons.soup_kitchen_outlined),
          label: const Text('以鍮??쒖옉'),
        ),
      ],
      'PREPARING' => [
        FilledButton.icon(
          key: const Key('ready-order'),
          onPressed: _processing
              ? null
              : () => _transition(SellerOrderCommand.ready),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('以鍮??꾨즺'),
        ),
      ],
      'READY' => [
        FilledButton.icon(
          key: const Key('complete-order'),
          onPressed: _processing
              ? null
              : () => _transition(SellerOrderCommand.complete),
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('二쇰Ц ?꾨즺'),
        ),
      ],
      _ => <Widget>[],
    };

    if (actions.isEmpty) {
      return actions;
    }

    return [...actions, const SizedBox(height: PopqSpacing.sm)];
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) return;

    final client = _realtimeClient;
    if (client == null) {
      _updatePollingForConnection();
      return;
    }

    final connectionEpoch = client.connectionEpoch;
    if (client.isConnected && connectionEpoch != _lastConnectionEpoch) {
      _lastConnectionEpoch = connectionEpoch;
      unawaited(_syncSilently());
    }

    _updatePollingForConnection();
  }

  void _subscribeToOrder() {
    _orderSubscription?.cancel();
    _orderSubscription = null;

    final client = _realtimeClient;
    if (client == null) return;

    int storeId;
    try {
      storeId = _storeId;
    } catch (_) {
      return;
    }

    _orderSubscription = client.subscribeToStoreOrders(
      storeId: storeId,
      onEvent: _handleOrderEvent,
      onError: (error) {
        debugPrint('?먮ℓ??二쇰Ц ?곸꽭 ?ㅼ떆媛?援щ룆 ?ㅻ쪟: $error');
      },
    );
  }

  void _handleOrderEvent(PopqOrderRealtimeEvent event) {
    if (!mounted ||
        event.storeId != _storeId ||
        event.orderPublicId != widget.orderPublicId) {
      return;
    }

    final current = _order;
    if (current == null) {
      unawaited(_load());
      return;
    }

    if (event.isDuplicateOrOlderThan(current.version)) {
      return;
    }

    final knownVersion = current.version;
    setState(() {
      _order = current.copyWith(
        status: event.currentStatus,
        version: event.version,
      );
    });

    // ACCEPTED??以鍮꾩떆媛꾩쿂???대깽?몄뿉 ?ы븿?섏? ?딆? ?꾨뱶??
    // ?대깽??吏곸쟾 踰꾩쟾??湲곗??쇰줈 /sync ?섏뿬 ?꾩껜 二쇰Ц ?ㅻ깄?룹쑝濡?蹂댁젙?쒕떎.
    unawaited(_syncFromKnownVersion(knownVersion));
  }

  Future<void> _syncFromKnownVersion(int knownVersion) async {
    try {
      final result = await widget.repository.sync(
        _storeId,
        widget.orderPublicId,
        knownVersion,
      );

      if (!mounted) return;

      final refreshed = result.order;
      if (refreshed != null) {
        setState(() {
          final current = _order;
          if (current == null || refreshed.version >= current.version) {
            _order = refreshed;
          }
        });
      }

      final latest = _order;
      if (latest != null && _shouldLoadPayment(latest)) {
        await _loadPayment();
      }
      if (latest?.status == 'COMPLETED') {
        await _loadReview();
      }
    } catch (error) {
      debugPrint('?먮ℓ??二쇰Ц ?곸꽭 ?대깽??蹂댁젙 ?ㅻ쪟: $error');
    }
  }

  Future<void> _syncSilently() async {
    final current = _order;
    if (!mounted || !_isAppActive) return;

    if (current == null) {
      await _load();
      return;
    }

    try {
      final result = await widget.repository.sync(
        _storeId,
        current.orderPublicId,
        current.version,
      );

      if (!mounted) return;

      final refreshed = result.order;
      if (refreshed != null) {
        setState(() {
          final latest = _order;
          if (latest == null || refreshed.version >= latest.version) {
            _order = refreshed;
          }
        });
      }

      final latest = _order;
      if (latest != null && _shouldLoadPayment(latest)) {
        await _loadPayment();
      }
      if (latest?.status == 'COMPLETED') {
        await _loadReview();
      }
    } catch (error) {
      debugPrint('?먮ℓ??二쇰Ц ?곸꽭 REST ?숆린???ㅻ쪟: $error');
    }
  }

  void _updatePollingForConnection() {
    final shouldUseRestFallback =
        _realtimeClient?.shouldUseRestFallback ?? true;

    if (_isAppActive && shouldUseRestFallback) {
      _startPolling();
      return;
    }

    _stopPolling();
  }

  void _startPolling() {
    if (!_isAppActive ||
        !(_realtimeClient?.shouldUseRestFallback ?? true) ||
        (_pollingTimer?.isActive ?? false)) {
      return;
    }

    _pollingTimer = Timer.periodic(
      _pollingInterval,
      (_) => unawaited(_syncSilently()),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await Future.wait([
        widget.repository.findOne(_storeId, widget.orderPublicId),
        widget.storeRepository.findOne(_storeId),
      ]);

      final order = result[0] as SellerOrder;
      final store = result[1] as SellerStore;

      if (!mounted) {
        return;
      }

      setState(() {
        final current = _order;
        if (current == null || order.version >= current.version) {
          _order = order;
        }
        _canRefund = store.myRole == 'OWNER' || store.myRole == 'MANAGER';
        _defaultPreparationMinutes = store.defaultPreparationMinutes ?? 10;
        _loading = false;
      });

      final latestOrder = _order;
      if (latestOrder != null && _shouldLoadPayment(latestOrder)) {
        await _loadPayment();
      }
      if (latestOrder?.status == 'COMPLETED') {
        await _loadReview();
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
        final refreshed = result.order;
        final currentOrder = _order;
        if (refreshed != null &&
            (currentOrder == null ||
                refreshed.version >= currentOrder.version)) {
          _order = refreshed;
        }

        _processing = false;
      });

      final latestOrder = _order;
      if (latestOrder != null && _shouldLoadPayment(latestOrder)) {
        await _loadPayment();
      }
      if (latestOrder?.status == 'COMPLETED') {
        await _loadReview();
      }

      _showMessage(
        result.refreshRequired ? '理쒖떊 二쇰Ц ?곹깭濡?媛깆떊?덉뒿?덈떎.' : '?대? 理쒖떊 ?곹깭?낅땲??',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _processing = false);

      _showMessage('理쒖떊 ?곹깭瑜??뺤씤?섏? 紐삵뻽?듬땲??');
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

    await _transition(SellerOrderCommand.reject, reason: reason);
  }

  Future<void> _accept() async {
    var minutes =
        const <int>[
          0,
          5,
          10,
          15,
          20,
          30,
          40,
          50,
        ].contains(_defaultPreparationMinutes)
        ? _defaultPreparationMinutes
        : 10;
    var applyAsDefault = false;
    final result = await showModalBottomSheet<({int minutes, bool apply})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PopqSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('以鍮꾩떆媛??좏깮', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: PopqSpacing.sm),
                Wrap(
                  spacing: PopqSpacing.xs,
                  runSpacing: PopqSpacing.xs,
                  children: [
                    for (final value in const <int>[
                      0,
                      5,
                      10,
                      15,
                      20,
                      30,
                      40,
                      50,
                    ])
                      ChoiceChip(
                        label: Text(value == 0 ? '利됱떆' : '$value遺?),
                        selected: minutes == value,
                        onSelected: (_) => setSheetState(() => minutes = value),
                      ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: applyAsDefault,
                  title: const Text('???쒓컙???ъ뾽??湲곕낯 以鍮꾩떆媛꾩쑝濡??ъ슜'),
                  onChanged: (value) =>
                      setSheetState(() => applyAsDefault = value ?? false),
                ),
                FilledButton(
                  key: const Key('confirm-accept-order'),
                  onPressed: () => Navigator.pop(context, (
                    minutes: minutes,
                    apply: applyAsDefault,
                  )),
                  child: const Text('二쇰Ц ?묒닔'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _transition(
      SellerOrderCommand.accept,
      preparationMinutes: result.minutes,
      applyAsStoreDefault: result.apply,
    );
  }

  Future<void> _transition(
    SellerOrderCommand command, {
    String? reason,
    int? preparationMinutes,
    bool applyAsStoreDefault = false,
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
        preparationMinutes: preparationMinutes,
        applyAsStoreDefault: applyAsStoreDefault,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final currentOrder = _order;
        if (currentOrder == null || updated.version >= currentOrder.version) {
          _order = updated;
        }
        _processing = false;
      });

      final latestOrder = _order ?? updated;
      _showMessage('${sellerOrderStatusLabel(latestOrder.status)} ?곹깭濡?蹂寃쏀뻽?듬땲??');

      if (_shouldLoadPayment(latestOrder)) {
        await _loadPayment();
      }
      if (latestOrder.status == 'COMPLETED') {
        await _loadReview();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _processing = false);

      _showMessage('二쇰Ц ?곹깭瑜?蹂寃쏀븯吏 紐삵뻽?듬땲?? 理쒖떊 ?곹깭瑜??뺤씤??二쇱꽭??');
    }
  }

  Future<void> _loadPayment() async {
    final order = _order;

    if (order == null || !_shouldLoadPayment(order)) {
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

    if (payment == null || payment.refundableAmount <= 0 || _processing) {
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RefundDialog(amount: payment.refundableAmount),
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

      _showMessage('?꾩븸 ?섎텋???꾨즺?덉뒿?덈떎.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _processing = false);

      _showMessage('?섎텋??泥섎━?섏? 紐삵뻽?듬땲??');
    }
  }

  bool _shouldLoadPayment(SellerOrder order) {
    return switch (order.status) {
      'COMPLETED' || 'CANCELED' || 'REJECTED' => true,
      _ => false,
    };
  }

  SellerOrderStatusHistory? _terminalStatusHistory(SellerOrder order) {
    for (final history in order.statusHistory.reversed) {
      if (history.currentStatus == 'CANCELED' ||
          history.currentStatus == 'REJECTED') {
        return history;
      }
    }
    return null;
  }

  Widget _cancellationSection(
    SellerOrder order,
    SellerOrderStatusHistory history,
  ) {
    final isRejected = history.currentStatus == 'REJECTED';
    final reason = history.reason?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isRejected
                      ? Icons.block_rounded
                      : Icons.cancel_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: PopqSpacing.sm),
                Text(
                  isRejected ? '二쇰Ц 嫄곗젅 ?뺣낫' : '二쇰Ц 痍⑥냼 ?뺣낫',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: PopqSpacing.md),
            _PaymentRow(
              label: isRejected ? '嫄곗젅 二쇱껜' : '痍⑥냼 二쇱껜',
              value: _orderActorLabel(history.actorType),
            ),
            _PaymentRow(
              label: isRejected ? '嫄곗젅 ?ъ쑀' : '痍⑥냼 ?ъ쑀',
              value: reason == null || reason.isEmpty ? '?ъ쑀 ?놁쓬' : reason,
            ),
            _PaymentRow(
              label: isRejected ? '嫄곗젅 ?쒓컙' : '痍⑥냼 ?쒓컙',
              value: _formatDateTime(history.changedAt),
            ),
            if (order.status == 'CANCELED' || order.status == 'REJECTED') ...[
              const SizedBox(height: PopqSpacing.xs),
              Text(
                '寃곗젣??二쇰Ц? ?꾨옒 寃곗젣쨌?섎텋 ?곸뿭?먯꽌 ?섎텋 泥섎━ 寃곌낵瑜??뺤씤?????덉뒿?덈떎.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _refundHistoryCard(SellerRefund refund, int index) {
    final succeeded = refund.status == 'SUCCEEDED';
    final failed = refund.status == 'FAILED';

    return Container(
      margin: const EdgeInsets.only(top: PopqSpacing.sm),
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                succeeded
                    ? Icons.check_circle_outline_rounded
                    : failed
                        ? Icons.error_outline_rounded
                        : Icons.schedule_rounded,
                size: 20,
              ),
              const SizedBox(width: PopqSpacing.xs),
              Expanded(
                child: Text(
                  '?섎텋 $index',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Chip(label: Text(_refundStatusLabel(refund.status))),
            ],
          ),
          const SizedBox(height: PopqSpacing.xs),
          _PaymentRow(label: '?섎텋 湲덉븸', value: sellerWon(refund.amount)),
          _PaymentRow(
            label: '泥섎━ 二쇱껜',
            value: _refundRequesterLabel(refund.requesterType),
          ),
          _PaymentRow(label: '?섎텋 ?ъ쑀', value: refund.reason),
          _PaymentRow(
            label: '?붿껌 ?쒓컙',
            value: _formatDateTime(refund.requestedAt),
          ),
          if (refund.completedAt != null)
            _PaymentRow(
              label: '?꾨즺 ?쒓컙',
              value: _formatDateTime(refund.completedAt!),
            ),
          if (failed &&
              (refund.failureMessage?.trim().isNotEmpty ?? false))
            _PaymentRow(
              label: '?ㅽ뙣 ?ъ쑀',
              value: refund.failureMessage!.trim(),
            ),
        ],
      ),
    );
  }

  String _orderActorLabel(String actorType) {
    return switch (actorType) {
      'SELLER' => '?먮ℓ??,
      'CUSTOMER' => '援щℓ??,
      'ADMIN' => '愿由ъ옄',
      'SYSTEM' => '?쒖뒪??,
      'GUEST' => '鍮꾪쉶??援щℓ??,
      _ => actorType,
    };
  }

  String _paymentStatusLabel(String status) {
    return switch (status) {
      'PAID' => '寃곗젣 ?꾨즺',
      'REFUNDED' => '?섎텋 ?꾨즺',
      'CANCELED' => '寃곗젣 痍⑥냼',
      'PARTIALLY_REFUNDED' => '遺遺??섎텋',
      'FAILED' => '寃곗젣 ?ㅽ뙣',
      _ => '寃곗젣 ?뺤씤 以?,
    };
  }

  String _refundStatusLabel(String status) {
    return switch (status) {
      'SUCCEEDED' => '?섎텋 ?꾨즺',
      'FAILED' => '?섎텋 ?ㅽ뙣',
      'PROCESSING' => '泥섎━ 以?,
      _ => '?붿껌??,
    };
  }

  String _refundRequesterLabel(String requester) {
    return switch (requester) {
      'SELLER' => '?먮ℓ???붿껌',
      'ADMIN' => '愿由ъ옄 ?붿껌',
      'CUSTOMER' => '怨좉컼 ?붿껌',
      _ => '鍮꾪쉶???붿껌',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showTopSnackBar(SnackBar(content: Text(message)));
  }

  Widget _reviewSection() {
    final review = _review;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.md),
        child: review == null
            ? const Text('??二쇰Ц?먮뒗 ?꾩쭅 ?묒꽦??由щ럭媛 ?놁뒿?덈떎.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '怨좉컼 由щ럭 ${List.filled(review.rating, '??).join()}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (review.content?.isNotEmpty ?? false) ...[
                    const SizedBox(height: PopqSpacing.sm),
                    Text(review.content!),
                  ],
                  if (review.sellerReply?.isNotEmpty ?? false) ...[
                    const Divider(),
                    Text('?먮ℓ???듦?\n${review.sellerReply!}'),
                  ],
                  if (_canRefund) ...[
                    const SizedBox(height: PopqSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _editReviewReply(review),
                          child: Text(
                            review.sellerReply == null ? '?듦? ?묒꽦' : '?듦? ?섏젙',
                          ),
                        ),
                        if (review.sellerReply != null)
                          TextButton(
                            onPressed: () => _deleteReviewReply(review),
                            child: const Text('?듦? ??젣'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _loadReview() async {
    final order = _order;
    if (order == null || order.status != 'COMPLETED') return;
    try {
      final review = await widget.reviewRepository.findByOrder(
        _storeId,
        order.orderPublicId,
      );
      if (mounted) setState(() => _review = review);
    } catch (_) {
      if (mounted) setState(() => _review = null);
    }
  }

  Future<void> _editReviewReply(SellerReview review) async {
    List<SellerReviewReplyTemplate> templates;
    try {
      templates = await widget.reviewRepository.findReplyTemplates(_storeId);
    } catch (_) {
      templates = const <SellerReviewReplyTemplate>[];
    }
    if (!mounted) return;

    final controller = TextEditingController(text: review.sellerReply ?? '');
    var selectedTemplateId = 0;
    final value = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('由щ럭 ?듦?'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<int>(
                  initialValue: selectedTemplateId,
                  decoration: const InputDecoration(labelText: '????듦? 臾멸뎄'),
                  items: <DropdownMenuItem<int>>[
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('??λ맂 ?듦? ?놁쓬'),
                    ),
                    ...templates.map(
                      (template) => DropdownMenuItem<int>(
                        value: template.templateId,
                        child: Text(
                          template.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (int? value) {
                    if (value == null) return;
                    setDialogState(() => selectedTemplateId = value);
                    if (value == 0) return;
                    controller.text = templates
                        .firstWhere((item) => item.templateId == value)
                        .content;
                  },
                ),
                const SizedBox(height: PopqSpacing.sm),
                TextField(
                  controller: controller,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: '?듦? ?댁슜'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('痍⑥냼'),
            ),
            FilledButton(
              onPressed: () {
                final reply = controller.text.trim();
                if (reply.isNotEmpty) Navigator.pop(context, reply);
              },
              child: const Text('?묒꽦 ?꾨즺'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    try {
      final saved =
          await widget.reviewRepository.reply(_storeId, review.reviewId, value);
      if (mounted) setState(() => _review = saved);
    } catch (_) {
      if (mounted) _showMessage('?듦?????ν븯吏 紐삵뻽?듬땲??');
    }
  }

  Future<void> _deleteReviewReply(SellerReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('?듦?????젣?좉퉴??'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('痍⑥냼'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('??젣'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final saved =
          await widget.reviewRepository.deleteReply(_storeId, review.reviewId);
      if (mounted) setState(() => _review = saved);
    } catch (_) {
      if (mounted) _showMessage('?듦?????젣?섏? 紐삵뻽?듬땲??');
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.month}/${local.day} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  void dispose() {
    _stopPolling();
    _orderSubscription?.cancel();
    _orderSubscription = null;
    _realtimeClient?.removeListener(_handleRealtimeClientChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: PopqSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
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
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('二쇰Ц 嫄곗젅'),
      content: TextField(
        key: const Key('reject-reason'),
        controller: _controller,
        maxLength: 500,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '嫄곗젅 ?ъ쑀',
          hintText: '?? ?щ즺媛 ?뚯쭊?섏뿀?듬땲??',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('痍⑥냼'),
        ),
        FilledButton(
          key: const Key('confirm-reject'),
          onPressed: () {
            final value = _controller.text.trim();

            Navigator.pop(context, value.isEmpty ? '?먮ℓ??二쇰Ц 嫄곗젅' : value);
          },
          child: const Text('嫄곗젅 ?뺤젙'),
        ),
      ],
    );
  }
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.amount});

  final int amount;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('?꾩븸 ?섎텋 ?뺤씤'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${sellerWon(widget.amount)} ?꾩븸???섎텋?⑸땲??'),
            const SizedBox(height: PopqSpacing.sm),
            TextField(
              key: const Key('refund-reason'),
              controller: _controller,
              autofocus: true,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '?섎텋 ?ъ쑀',
                hintText: '怨좉컼?먭쾶 ?덈궡???섎텋 ?ъ쑀',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('痍⑥냼'),
        ),
        FilledButton(
          key: const Key('confirm-refund'),
          onPressed: () {
            final value = _controller.text.trim();

            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
          child: const Text('?꾩븸 ?섎텋 ?뺤젙'),
        ),
      ],
    );
  }
}

