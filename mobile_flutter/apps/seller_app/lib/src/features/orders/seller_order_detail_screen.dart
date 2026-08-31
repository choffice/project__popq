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

    if (storeId == null) {
      throw StateError('selected store is missing');
    }

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
      appBar: AppBar(
        title: const Text('판매자 주문 상세'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(
        message: '최신 주문 상태를 확인하고 있어요.',
      );
    }

    if (_error != null || _order == null) {
      return PopqErrorView(
        message: '선택한 스토어의 주문 상세를 불러오지 못했습니다.',
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
                  backgroundColor: sellerOrderStatusColor(
                    order.status,
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: sellerOrderStatusForegroundColor(
                      order.status,
                    ),
                    size: 30,
                  ),
                ),
                const SizedBox(
                  height: PopqSpacing.sm,
                ),
                Text(
                  sellerOrderStatusLabel(
                    order.status,
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(
                  height: PopqSpacing.xs,
                ),
                Text(
                  '${sellerOrderTypeLabel(order.orderType)} · '
                      '${formatPopqOrderNumber(order.orderPublicId)}',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          Text(
            '주문 상품',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(
            height: PopqSpacing.sm,
          ),

          for (final item in order.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.productName,
              ),
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
              trailing: Text(
                sellerWon(
                  item.itemTotalPrice,
                ),
              ),
            ),

          const SizedBox(
            height: PopqSpacing.sm,
          ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(
                PopqSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(
                    width: PopqSpacing.md,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '요청사항',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(
                          height: PopqSpacing.xs,
                        ),
                        Text(
                          requestMessage ?? '요청사항 없음',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
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
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            _cancellationSection(
              order,
              terminalHistory,
            ),
          ],

          const SizedBox(
            height: PopqSpacing.sm,
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
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            trailing: Text(
              sellerWon(
                order.totalAmount,
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),

          if (order.preparationMinutes != null) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: PopqSpacing.md,
                  vertical: PopqSpacing.xs,
                ),
                leading: const Icon(
                  Icons.timer_outlined,
                ),
                title: Text(
                  order.preparationMinutes == 0
                      ? '준비 즉시 시작'
                      : '준비시간 ${order.preparationMinutes}분',
                ),
                subtitle: order.estimatedReadyAt == null
                    ? null
                    : Text(
                  '예상 완료 ${_formatDateTime(order.estimatedReadyAt!)}',
                ),
                trailing:
                order.status == 'ACCEPTED' ||
                    order.status == 'PREPARING'
                    ? TextButton.icon(
                  key: const Key(
                    'edit-preparation-time',
                  ),
                  onPressed: _processing
                      ? null
                      : () => _editPreparationTime(
                    order,
                  ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    '시간 수정',
                  ),
                )
                    : null,
              ),
            ),
          ],

          if (_shouldLoadPayment(order)) ...[
            const SizedBox(
              height: PopqSpacing.lg,
            ),
            _paymentSection(
              order,
            ),
          ],

          if (order.status == 'COMPLETED') ...[
            const SizedBox(
              height: PopqSpacing.lg,
            ),
            _reviewSection(),
          ],

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          ..._actionButtons(
            order,
          ),

          OutlinedButton.icon(
            onPressed: _processing
                ? null
                : _sync,
            icon: const Icon(
              Icons.sync_rounded,
            ),
            label: const Text(
              '최신 상태 확인',
            ),
          ),

          const SizedBox(
            height: PopqSpacing.sm,
          ),

          Text(
            '서버 버전 ${order.version} · '
                '선택된 스토어 #${order.storeId} 전용 주문',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _paymentSection(
      SellerOrder order,
      ) {
    if (_paymentLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(
            PopqSpacing.lg,
          ),
          child: Column(
            children: [
              LinearProgressIndicator(),
              SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(
                '결제·환불 정보를 확인하고 있어요.',
              ),
            ],
          ),
        ),
      );
    }

    if (_paymentError != null ||
        _payment == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(
            PopqSpacing.lg,
          ),
          child: Column(
            children: [
              const Text(
                '결제·환불 정보를 불러오지 못했습니다.',
              ),
              TextButton(
                key: const Key(
                  'retry-payment',
                ),
                onPressed: _processing
                    ? null
                    : _loadPayment,
                child: const Text(
                  '다시 시도',
                ),
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
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
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
                    _paymentStatusLabel(
                      payment.paymentStatus,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: PopqSpacing.sm,
            ),

            _PaymentRow(
              label: '결제 수단',
              value: payment.paymentMethod,
            ),

            _PaymentRow(
              label: '승인 금액',
              value: sellerWon(
                payment.approvedAmount,
              ),
            ),

            _PaymentRow(
              label: '환불 금액',
              value: sellerWon(
                payment.refundedAmount,
              ),
            ),

            _PaymentRow(
              label: '환불 가능 금액',
              value: sellerWon(
                payment.refundableAmount,
              ),
            ),

            if (payment.refunds.isNotEmpty) ...[
              const Divider(),

              const Text(
                '환불 이력',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: PopqSpacing.xs,
              ),

              for (
              var index = 0;
              index < payment.refunds.length;
              index++
              )
                _refundHistoryCard(
                  payment.refunds[index],
                  index + 1,
                ),
            ],

            if (canRequestRefund) ...[
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              FilledButton.icon(
                key: const Key(
                  'refund-order',
                ),
                onPressed: _processing
                    ? null
                    : () => _refund(
                  order,
                ),
                icon: const Icon(
                  Icons.currency_exchange_rounded,
                ),
                label: Text(
                  '${sellerWon(payment.refundableAmount)} 전액 환불',
                ),
              ),
            ] else if (!_canRefund &&
                payment.refundableAmount > 0) ...[
              const SizedBox(
                height: PopqSpacing.sm,
              ),
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

  List<Widget> _actionButtons(
      SellerOrder order,
      ) {
    final actions = switch (order.status) {
      'PLACED' => [
        FilledButton.icon(
          key: const Key(
            'accept-order',
          ),
          onPressed: _processing
              ? null
              : _accept,
          icon: const Icon(
            Icons.check_circle_outline_rounded,
          ),
          label: const Text(
            '주문 접수',
          ),
        ),
        const SizedBox(
          height: PopqSpacing.sm,
        ),
        OutlinedButton.icon(
          key: const Key(
            'reject-order',
          ),
          onPressed: _processing
              ? null
              : _reject,
          icon: const Icon(
            Icons.cancel_outlined,
          ),
          label: const Text(
            '주문 거절',
          ),
        ),
      ],
      'ACCEPTED' => [
        FilledButton.icon(
          key: const Key(
            'prepare-order',
          ),
          onPressed: _processing
              ? null
              : () => _transition(
            SellerOrderCommand.prepare,
          ),
          icon: const Icon(
            Icons.soup_kitchen_outlined,
          ),
          label: const Text(
            '준비 시작',
          ),
        ),
      ],
      'PREPARING' => [
        FilledButton.icon(
          key: const Key(
            'ready-order',
          ),
          onPressed: _processing
              ? null
              : () => _transition(
            SellerOrderCommand.ready,
          ),
          icon: const Icon(
            Icons.notifications_active_outlined,
          ),
          label: const Text(
            '준비 완료',
          ),
        ),
      ],
      'READY' => [
        FilledButton.icon(
          key: const Key(
            'complete-order',
          ),
          onPressed: _processing
              ? null
              : () => _transition(
            SellerOrderCommand.complete,
          ),
          icon: const Icon(
            Icons.task_alt_rounded,
          ),
          label: const Text(
            '주문 완료',
          ),
        ),
      ],
      _ => <Widget>[],
    };

    if (actions.isEmpty) {
      return actions;
    }

    return [
      ...actions,
      const SizedBox(
        height: PopqSpacing.sm,
      ),
    ];
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) {
      return;
    }

    final client = _realtimeClient;

    if (client == null) {
      _updatePollingForConnection();
      return;
    }

    final connectionEpoch = client.connectionEpoch;

    if (client.isConnected &&
        connectionEpoch != _lastConnectionEpoch) {
      _lastConnectionEpoch = connectionEpoch;

      unawaited(
        _syncSilently(),
      );
    }

    _updatePollingForConnection();
  }

  void _subscribeToOrder() {
    _orderSubscription?.cancel();
    _orderSubscription = null;

    final client = _realtimeClient;

    if (client == null) {
      return;
    }

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
        debugPrint(
          '판매자 주문 상세 실시간 구독 오류: $error',
        );
      },
    );
  }

  void _handleOrderEvent(
      PopqOrderRealtimeEvent event,
      ) {
    if (!mounted ||
        event.storeId != _storeId ||
        event.orderPublicId != widget.orderPublicId) {
      return;
    }

    final current = _order;

    if (current == null) {
      unawaited(
        _load(),
      );
      return;
    }

    if (event.isDuplicateOrOlderThan(
      current.version,
    )) {
      return;
    }

    final knownVersion = current.version;

    setState(() {
      _order = current.copyWith(
        status: event.currentStatus,
        version: event.version,
      );
    });

    // 준비시간처럼 실시간 이벤트 payload 자체에 없는 필드는
    // 이벤트 직전 version 기준으로 /sync하여 전체 주문 데이터로 다시 맞춘다.
    unawaited(
      _syncFromKnownVersion(
        knownVersion,
      ),
    );
  }

  Future<void> _syncFromKnownVersion(
      int knownVersion,
      ) async {
    try {
      final result = await widget.repository.sync(
        _storeId,
        widget.orderPublicId,
        knownVersion,
      );

      if (!mounted) {
        return;
      }

      final refreshed = result.order;

      if (refreshed != null) {
        setState(() {
          final current = _order;

          if (current == null ||
              refreshed.version >= current.version) {
            _order = refreshed;
          }
        });
      }

      final latest = _order;

      if (latest != null &&
          _shouldLoadPayment(latest)) {
        await _loadPayment();
      }

      if (latest?.status == 'COMPLETED') {
        await _loadReview();
      }
    } catch (error) {
      debugPrint(
        '판매자 주문 상세 이벤트 보정 오류: $error',
      );
    }
  }

  Future<void> _syncSilently() async {
    final current = _order;

    if (!mounted ||
        !_isAppActive) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      final refreshed = result.order;

      if (refreshed != null) {
        setState(() {
          final latest = _order;

          if (latest == null ||
              refreshed.version >= latest.version) {
            _order = refreshed;
          }
        });
      }

      final latest = _order;

      if (latest != null &&
          _shouldLoadPayment(latest)) {
        await _loadPayment();
      }

      if (latest?.status == 'COMPLETED') {
        await _loadReview();
      }
    } catch (error) {
      debugPrint(
        '판매자 주문 상세 REST 동기화 오류: $error',
      );
    }
  }

  void _updatePollingForConnection() {
    final shouldUseRestFallback =
        _realtimeClient?.shouldUseRestFallback ?? true;

    if (_isAppActive &&
        shouldUseRestFallback) {
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
          (_) => unawaited(
        _syncSilently(),
      ),
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
        widget.repository.findOne(
          _storeId,
          widget.orderPublicId,
        ),
        widget.storeRepository.findOne(
          _storeId,
        ),
      ]);

      final order = result[0] as SellerOrder;
      final store = result[1] as SellerStore;

      if (!mounted) {
        return;
      }

      setState(() {
        final current = _order;

        if (current == null ||
            order.version >= current.version) {
          _order = order;
        }

        _canRefund =
            store.myRole == 'OWNER' ||
                store.myRole == 'MANAGER';

        _defaultPreparationMinutes =
            store.defaultPreparationMinutes ?? 10;

        _loading = false;
      });

      final latestOrder = _order;

      if (latestOrder != null &&
          _shouldLoadPayment(latestOrder)) {
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

    if (current == null ||
        _processing) {
      return;
    }

    setState(
          () => _processing = true,
    );

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

      if (latestOrder != null &&
          _shouldLoadPayment(latestOrder)) {
        await _loadPayment();
      }

      if (latestOrder?.status == 'COMPLETED') {
        await _loadReview();
      }

      _showMessage(
        result.refreshRequired
            ? '최신 주문 상태로 갱신했습니다.'
            : '이미 최신 상태입니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(
            () => _processing = false,
      );

      _showMessage(
        '최신 상태를 확인하지 못했습니다.',
      );
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );

    if (reason == null ||
        !mounted) {
      return;
    }

    await _transition(
      SellerOrderCommand.reject,
      reason: reason,
    );
  }

  Future<void> _accept() async {
    final order = _order;

    if (order == null ||
        _processing) {
      return;
    }

    const availableMinutes = <int>[
      0,
      5,
      10,
      15,
      20,
      30,
      40,
      50,
    ];

    setState(
          () => _processing = true,
    );

    SellerWaitTimeRecommendation? recommendation;

    try {
      recommendation =
      await widget.repository.findWaitTimeRecommendation(
        _storeId,
        order.orderPublicId,
      );
    } catch (_) {
      recommendation = null;
    }

    if (!mounted) {
      return;
    }

    setState(
          () => _processing = false,
    );

    final recommendedMinutes =
        recommendation?.recommendedMinutes;

    var minutes =
    recommendedMinutes != null &&
        availableMinutes.contains(
          recommendedMinutes,
        )
        ? recommendedMinutes
        : availableMinutes.contains(
      _defaultPreparationMinutes,
    )
        ? _defaultPreparationMinutes
        : 10;

    var applyAsDefault = false;

    final result =
    await showModalBottomSheet<
        ({int minutes, bool apply})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (
            context,
            setSheetState,
            ) =>
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: PopqSpacing.lg,
                  top: PopqSpacing.lg,
                  right: PopqSpacing.lg,
                  bottom:
                  MediaQuery.viewInsetsOf(context).bottom +
                      PopqSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '준비시간 선택',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(
                      height: PopqSpacing.sm,
                    ),

                    _WaitTimeRecommendationCard(
                      recommendation: recommendation,
                    ),

                    const SizedBox(
                      height: PopqSpacing.md,
                    ),

                    Wrap(
                      spacing: PopqSpacing.xs,
                      runSpacing: PopqSpacing.xs,
                      children: [
                        for (final value in availableMinutes)
                          ChoiceChip(
                            label: Text(
                              value == recommendedMinutes
                                  ? value == 0
                                  ? '즉시 · 추천'
                                  : '$value분 · 추천'
                                  : value == 0
                                  ? '즉시'
                                  : '$value분',
                            ),
                            selected: minutes == value,
                            onSelected: (_) =>
                                setSheetState(
                                      () => minutes = value,
                                ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: PopqSpacing.xs,
                    ),

                    Text(
                      '추천 시간은 참고용이에요. 매장 상황에 맞게 직접 변경할 수 있습니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: applyAsDefault,
                      title: const Text(
                        '이 시간을 사업장 기본 준비시간으로 사용',
                      ),
                      onChanged: (value) =>
                          setSheetState(
                                () =>
                            applyAsDefault =
                                value ?? false,
                          ),
                    ),

                    FilledButton(
                      key: const Key(
                        'confirm-accept-order',
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        (
                        minutes: minutes,
                        apply: applyAsDefault,
                        ),
                      ),
                      child: const Text(
                        '주문 접수',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );

    if (result == null ||
        !mounted) {
      return;
    }

    await _transition(
      SellerOrderCommand.accept,
      preparationMinutes: result.minutes,
      applyAsStoreDefault: result.apply,
    );
  }

  Future<void> _editPreparationTime(
      SellerOrder order,
      ) async {
    if (_processing) {
      return;
    }

    if (order.status != 'ACCEPTED' &&
        order.status != 'PREPARING') {
      _showMessage(
        '현재 주문 상태에서는 준비시간을 수정할 수 없습니다.',
      );
      return;
    }

    const availableMinutes = <int>[
      0,
      5,
      10,
      15,
      20,
      30,
      40,
      50,
    ];

    var minutes =
    order.preparationMinutes != null &&
        availableMinutes.contains(
          order.preparationMinutes,
        )
        ? order.preparationMinutes!
        : _defaultPreparationMinutes;

    if (!availableMinutes.contains(
      minutes,
    )) {
      minutes = 10;
    }

    var applyAsDefault = false;

    final result =
    await showModalBottomSheet<
        ({int minutes, bool apply})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (
            context,
            setSheetState,
            ) =>
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: PopqSpacing.lg,
                  top: PopqSpacing.lg,
                  right: PopqSpacing.lg,
                  bottom:
                  MediaQuery.viewInsetsOf(context).bottom +
                      PopqSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                        ),
                        const SizedBox(
                          width: PopqSpacing.sm,
                        ),
                        Expanded(
                          child: Text(
                            '예상 준비시간 수정',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: PopqSpacing.xs,
                    ),

                    Text(
                      '접수 시점 기준 총 준비시간을 다시 설정합니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: PopqSpacing.md,
                    ),

                    Wrap(
                      spacing: PopqSpacing.xs,
                      runSpacing: PopqSpacing.xs,
                      children: [
                        for (final value in availableMinutes)
                          ChoiceChip(
                            label: Text(
                              value == 0
                                  ? '즉시'
                                  : '$value분',
                            ),
                            selected: minutes == value,
                            onSelected: (_) =>
                                setSheetState(
                                      () => minutes = value,
                                ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: PopqSpacing.md,
                    ),

                    Container(
                      padding: const EdgeInsets.all(
                        PopqSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                          ),
                          const SizedBox(
                            width: PopqSpacing.sm,
                          ),
                          Expanded(
                            child: Text(
                              order.preparationMinutes == null
                                  ? '현재 준비시간 정보가 없습니다.'
                                  : order.preparationMinutes == 0
                                  ? '현재 즉시로 설정되어 있어요.'
                                  : '현재 ${order.preparationMinutes}분으로 설정되어 있어요.',
                            ),
                          ),
                        ],
                      ),
                    ),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: applyAsDefault,
                      title: const Text(
                        '이 시간을 사업장 기본 준비시간으로 사용',
                      ),
                      onChanged: (value) =>
                          setSheetState(
                                () =>
                            applyAsDefault =
                                value ?? false,
                          ),
                    ),

                    FilledButton(
                      key: const Key(
                        'confirm-edit-preparation-time',
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        (
                        minutes: minutes,
                        apply: applyAsDefault,
                        ),
                      ),
                      child: const Text(
                        '준비시간 변경',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );

    if (result == null ||
        !mounted) {
      return;
    }

    if (result.minutes ==
        order.preparationMinutes &&
        !result.apply) {
      _showMessage(
        '준비시간이 변경되지 않았습니다.',
      );
      return;
    }

    setState(
          () => _processing = true,
    );

    try {
      final updated =
      await widget.repository.updatePreparationTime(
        _storeId,
        order.orderPublicId,
        preparationMinutes: result.minutes,
        applyAsStoreDefault: result.apply,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final current = _order;

        if (current == null ||
            updated.version >= current.version) {
          _order = updated;
        }

        if (result.apply) {
          _defaultPreparationMinutes =
              result.minutes;
        }

        _processing = false;
      });

      _showMessage(
        result.minutes == 0
            ? '준비시간을 즉시로 변경했습니다.'
            : '준비시간을 ${result.minutes}분으로 변경했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(
            () => _processing = false,
      );

      _showMessage(
        '준비시간을 변경하지 못했습니다. 최신 주문 상태를 확인해 주세요.',
      );
    }
  }

  Future<void> _transition(
      SellerOrderCommand command, {
        String? reason,
        int? preparationMinutes,
        bool applyAsStoreDefault = false,
      }) async {
    final current = _order;

    if (current == null ||
        _processing) {
      return;
    }

    setState(
          () => _processing = true,
    );

    try {
      final updated =
      await widget.repository.transition(
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

        if (currentOrder == null ||
            updated.version >= currentOrder.version) {
          _order = updated;
        }

        _processing = false;
      });

      final latestOrder =
          _order ?? updated;

      _showMessage(
        '${sellerOrderStatusLabel(latestOrder.status)} 상태로 변경했습니다.',
      );

      if (_shouldLoadPayment(
        latestOrder,
      )) {
        await _loadPayment();
      }

      if (latestOrder.status == 'COMPLETED') {
        await _loadReview();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(
            () => _processing = false,
      );

      _showMessage(
        '주문 상태를 변경하지 못했습니다. 최신 상태를 확인해 주세요.',
      );
    }
  }

  Future<void> _loadPayment() async {
    final order = _order;

    if (order == null ||
        !_shouldLoadPayment(order)) {
      return;
    }

    setState(() {
      _paymentLoading = true;
      _paymentError = null;
    });

    try {
      final payment =
      await widget.repository.findPayment(
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

  Future<void> _refund(
      SellerOrder order,
      ) async {
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

    if (reason == null ||
        !mounted) {
      return;
    }

    setState(
          () => _processing = true,
    );

    try {
      final updated =
      await widget.repository.refund(
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

      _showMessage(
        '전액 환불을 완료했습니다.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(
            () => _processing = false,
      );

      _showMessage(
        '환불을 처리하지 못했습니다.',
      );
    }
  }

  bool _shouldLoadPayment(
      SellerOrder order,
      ) {
    return switch (order.status) {
      'COMPLETED' ||
      'CANCELED' ||
      'REJECTED' =>
      true,
      _ => false,
    };
  }

  SellerOrderStatusHistory?
  _terminalStatusHistory(
      SellerOrder order,
      ) {
    for (final history
    in order.statusHistory.reversed) {
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
    final isRejected =
        history.currentStatus == 'REJECTED';

    final reason =
    history.reason?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isRejected
                      ? Icons.block_rounded
                      : Icons.cancel_outlined,
                  color:
                  Theme.of(context).colorScheme.error,
                ),
                const SizedBox(
                  width: PopqSpacing.sm,
                ),
                Text(
                  isRejected
                      ? '주문 거절 정보'
                      : '주문 취소 정보',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: PopqSpacing.md,
            ),

            _PaymentRow(
              label:
              isRejected
                  ? '거절 주체'
                  : '취소 주체',
              value:
              _orderActorLabel(
                history.actorType,
              ),
            ),

            _PaymentRow(
              label:
              isRejected
                  ? '거절 사유'
                  : '취소 사유',
              value:
              reason == null ||
                  reason.isEmpty
                  ? '사유 없음'
                  : reason,
            ),

            _PaymentRow(
              label:
              isRejected
                  ? '거절 시간'
                  : '취소 시간',
              value:
              _formatDateTime(
                history.changedAt,
              ),
            ),

            if (order.status == 'CANCELED' ||
                order.status == 'REJECTED') ...[
              const SizedBox(
                height: PopqSpacing.xs,
              ),
              Text(
                '결제된 주문은 아래 결제·환불 영역에서 환불 처리 결과를 확인할 수 있습니다.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                  Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _refundHistoryCard(
      SellerRefund refund,
      int index,
      ) {
    final succeeded =
        refund.status == 'SUCCEEDED';

    final failed =
        refund.status == 'FAILED';

    return Container(
      margin: const EdgeInsets.only(
        top: PopqSpacing.sm,
      ),
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerLowest,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color:
          Theme.of(context)
              .colorScheme
              .outlineVariant,
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
              const SizedBox(
                width: PopqSpacing.xs,
              ),
              Expanded(
                child: Text(
                  '환불 $index',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  _refundStatusLabel(
                    refund.status,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: PopqSpacing.xs,
          ),

          _PaymentRow(
            label: '환불 금액',
            value: sellerWon(
              refund.amount,
            ),
          ),

          _PaymentRow(
            label: '처리 주체',
            value: _refundRequesterLabel(
              refund.requesterType,
            ),
          ),

          _PaymentRow(
            label: '환불 사유',
            value: refund.reason,
          ),

          _PaymentRow(
            label: '요청 시간',
            value: _formatDateTime(
              refund.requestedAt,
            ),
          ),

          if (refund.completedAt != null)
            _PaymentRow(
              label: '완료 시간',
              value: _formatDateTime(
                refund.completedAt!,
              ),
            ),

          if (failed &&
              (refund.failureMessage
                  ?.trim()
                  .isNotEmpty ??
                  false))
            _PaymentRow(
              label: '실패 사유',
              value:
              refund.failureMessage!.trim(),
            ),
        ],
      ),
    );
  }

  String _orderActorLabel(
      String actorType,
      ) {
    return switch (actorType) {
      'SELLER' => '판매자',
      'CUSTOMER' => '구매자',
      'ADMIN' => '관리자',
      'SYSTEM' => '시스템',
      'GUEST' => '비회원 구매자',
      _ => actorType,
    };
  }

  String _paymentStatusLabel(
      String status,
      ) {
    return switch (status) {
      'PAID' => '결제 완료',
      'REFUNDED' => '환불 완료',
      'CANCELED' => '결제 취소',
      'PARTIALLY_REFUNDED' => '부분 환불',
      'FAILED' => '결제 실패',
      _ => '결제 확인 중',
    };
  }

  String _refundStatusLabel(
      String status,
      ) {
    return switch (status) {
      'SUCCEEDED' => '환불 완료',
      'FAILED' => '환불 실패',
      'PROCESSING' => '처리 중',
      _ => '요청됨',
    };
  }

  String _refundRequesterLabel(
      String requester,
      ) {
    return switch (requester) {
      'SELLER' => '판매자 요청',
      'ADMIN' => '관리자 요청',
      'CUSTOMER' => '고객 요청',
      _ => '비회원 요청',
    };
  }

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(
      context,
    ).showTopSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  Widget _reviewSection() {
    final review = _review;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        child:
        review == null
            ? const Text(
          '이 주문에는 아직 작성된 리뷰가 없습니다.',
        )
            : Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (review.authorEmblemAssetPath != null) ...[
                  Image.asset(
                    review.authorEmblemAssetPath!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    semanticLabel:
                    review.authorEmblemLabel,
                  ),
                  const SizedBox(
                    width: PopqSpacing.xs,
                  ),
                ],
                Expanded(
                  child: Text(
                    review.authorBadgeTier ==
                        'NONE'
                        ? review.authorName
                        : '${review.authorName} · ${review.authorEmblemLabel}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  List.filled(
                    review.rating,
                    '★',
                  ).join(),
                ),
              ],
            ),

            if (review.content
                ?.isNotEmpty ??
                false) ...[
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Text(
                review.content!,
              ),
            ],

            if (review.imageUrl != null) ...[
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  12,
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    review.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                        _,
                        _,
                        _,
                        ) =>
                        Container(
                          color:
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          alignment:
                          Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                          ),
                        ),
                  ),
                ),
              ),
            ],

            if (review.sellerReply
                ?.isNotEmpty ??
                false) ...[
              const Divider(),
              Text(
                '판매자 답글\n${review.sellerReply!}',
              ),
            ],

            if (_canRefund) ...[
              const SizedBox(
                height: PopqSpacing.sm,
              ),
              Row(
                mainAxisAlignment:
                MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        _editReviewReply(
                          review,
                        ),
                    child: Text(
                      review.sellerReply == null
                          ? '답글 작성'
                          : '답글 수정',
                    ),
                  ),
                  if (review.sellerReply != null)
                    TextButton(
                      onPressed: () =>
                          _deleteReviewReply(
                            review,
                          ),
                      child: const Text(
                        '답글 삭제',
                      ),
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

    if (order == null ||
        order.status != 'COMPLETED') {
      return;
    }

    try {
      final review =
      await widget.reviewRepository.findByOrder(
        _storeId,
        order.orderPublicId,
      );

      if (mounted) {
        setState(
              () => _review = review,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
              () => _review = null,
        );
      }
    }
  }

  Future<void> _editReviewReply(
      SellerReview review,
      ) async {
    List<SellerReviewReplyTemplate> templates;

    try {
      templates =
      await widget.reviewRepository.findReplyTemplates(
        _storeId,
      );
    } catch (_) {
      templates =
      const <SellerReviewReplyTemplate>[];
    }

    if (!mounted) {
      return;
    }

    final controller =
    TextEditingController(
      text: review.sellerReply ?? '',
    );

    var selectedTemplateId = 0;

    final value =
    await showDialog<String>(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) =>
                AlertDialog(
                  title: const Text(
                    '리뷰 답글',
                  ),
                  content: SizedBox(
                    width: 460,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        DropdownButtonFormField<int>(
                          initialValue: selectedTemplateId,
                          decoration: const InputDecoration(
                            labelText: '대표 답글 문구',
                          ),
                          items: <DropdownMenuItem<int>>[
                            const DropdownMenuItem<int>(
                              value: 0,
                              child: Text(
                                '저장된 답글 없음',
                              ),
                            ),
                            ...templates.map(
                                  (template) =>
                                  DropdownMenuItem<int>(
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
                            if (value == null) {
                              return;
                            }

                            setDialogState(
                                  () =>
                              selectedTemplateId =
                                  value,
                            );

                            if (value == 0) {
                              return;
                            }

                            controller.text =
                                templates
                                    .firstWhere(
                                      (item) =>
                                  item.templateId ==
                                      value,
                                )
                                    .content;
                          },
                        ),

                        const SizedBox(
                          height: PopqSpacing.sm,
                        ),

                        TextField(
                          controller: controller,
                          maxLength: 1000,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: '답글 내용',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(
                            context,
                          ),
                      child: const Text(
                        '취소',
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        final reply =
                        controller.text.trim();

                        if (reply.isNotEmpty) {
                          Navigator.pop(
                            context,
                            reply,
                          );
                        }
                      },
                      child: const Text(
                        '작성 완료',
                      ),
                    ),
                  ],
                ),
          ),
    );

    controller.dispose();

    if (value == null ||
        !mounted) {
      return;
    }

    try {
      final saved =
      await widget.reviewRepository.reply(
        _storeId,
        review.reviewId,
        value,
      );

      if (mounted) {
        setState(
              () => _review = saved,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          '답글을 저장하지 못했습니다.',
        );
      }
    }
  }

  Future<void> _deleteReviewReply(
      SellerReview review,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text(
              '답글을 삭제할까요?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      false,
                    ),
                child: const Text(
                  '취소',
                ),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      true,
                    ),
                child: const Text(
                  '삭제',
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final saved =
      await widget.reviewRepository.deleteReply(
        _storeId,
        review.reviewId,
      );

      if (mounted) {
        setState(
              () => _review = saved,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          '답글을 삭제하지 못했습니다.',
        );
      }
    }
  }

  String _formatDateTime(
      DateTime value,
      ) {
    final local = value.toLocal();

    String two(
        int number,
        ) =>
        number
            .toString()
            .padLeft(
          2,
          '0',
        );

    return '${local.month}/${local.day} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  void dispose() {
    _stopPolling();

    _orderSubscription?.cancel();
    _orderSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    WidgetsBinding.instance.removeObserver(
      this,
    );

    super.dispose();
  }
}

class _WaitTimeRecommendationCard
    extends StatelessWidget {
  const _WaitTimeRecommendationCard({
    required this.recommendation,
  });

  final SellerWaitTimeRecommendation?
  recommendation;

  @override
  Widget build(
      BuildContext context,
      ) {
    final recommendation =
        this.recommendation;

    final colorScheme =
        Theme.of(context).colorScheme;

    if (recommendation == null) {
      return Container(
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        decoration: BoxDecoration(
          color:
          colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(
            16,
          ),
        ),
        child: const Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
            ),
            SizedBox(
              width: PopqSpacing.sm,
            ),
            Expanded(
              child: Text(
                '추천 준비시간을 불러오지 못했어요. 사업장 기본 준비시간으로 선택해 주세요.',
              ),
            ),
          ],
        ),
      );
    }

    final isAi =
        recommendation.isAi;

    final predictedMinutes =
        recommendation.predictedMinutes;

    return Container(
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color:
        colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAi
                    ? Icons.auto_awesome_rounded
                    : Icons.schedule_rounded,
                color:
                colorScheme.onPrimaryContainer,
              ),
              const SizedBox(
                width: PopqSpacing.xs,
              ),
              Expanded(
                child: Text(
                  isAi
                      ? 'AI 추천 준비시간'
                      : '기본 준비시간 추천',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    color:
                    colorScheme
                        .onPrimaryContainer,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: PopqSpacing.xs,
          ),

          Text(
            '${recommendation.recommendedMinutes}분',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
              color:
              colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),

          if (isAi &&
              predictedMinutes != null) ...[
            const SizedBox(
              height: 2,
            ),
            Text(
              'AI 예측 ${predictedMinutes.toStringAsFixed(1)}분을 '
                  '접수 가능한 준비시간으로 맞췄어요.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color:
                colorScheme
                    .onPrimaryContainer,
              ),
            ),
          ] else if (!isAi) ...[
            const SizedBox(
              height: 2,
            ),
            Text(
              'AI 예측을 사용할 수 없어 사업장 기본 준비시간을 추천했어요.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color:
                colorScheme
                    .onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountRow
    extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
  });

  final String label;
  final int amount;

  @override
  Widget build(
      BuildContext context,
      ) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
      ),
      trailing: Text(
        sellerWon(
          amount,
        ),
      ),
    );
  }
}

class _PaymentRow
    extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
            ),
          ),
          const SizedBox(
            width: PopqSpacing.md,
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectDialog
    extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() =>
      _RejectDialogState();
}

class _RejectDialogState
    extends State<_RejectDialog> {
  final TextEditingController _controller =
  TextEditingController();

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return AlertDialog(
      title: const Text(
        '주문 거절',
      ),
      content: TextField(
        key: const Key(
          'reject-reason',
        ),
        controller: _controller,
        maxLength: 500,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '거절 사유',
          hintText:
          '예: 재료가 소진되었습니다.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(
                context,
              ),
          child: const Text(
            '취소',
          ),
        ),
        FilledButton(
          key: const Key(
            'confirm-reject',
          ),
          onPressed: () {
            final value =
            _controller.text.trim();

            Navigator.pop(
              context,
              value.isEmpty
                  ? '판매자 주문 거절'
                  : value,
            );
          },
          child: const Text(
            '거절 확정',
          ),
        ),
      ],
    );
  }
}

class _RefundDialog
    extends StatefulWidget {
  const _RefundDialog({
    required this.amount,
  });

  final int amount;

  @override
  State<_RefundDialog> createState() =>
      _RefundDialogState();
}

class _RefundDialogState
    extends State<_RefundDialog> {
  final TextEditingController _controller =
  TextEditingController();

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return AlertDialog(
      title: const Text(
        '전액 환불 확인',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Text(
              '${sellerWon(widget.amount)} 전액을 환불합니다.',
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
            TextField(
              key: const Key(
                'refund-reason',
              ),
              controller: _controller,
              autofocus: true,
              maxLength: 500,
              decoration:
              const InputDecoration(
                labelText: '환불 사유',
                hintText:
                '고객에게 안내할 환불 사유',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(
                context,
              ),
          child: const Text(
            '취소',
          ),
        ),
        FilledButton(
          key: const Key(
            'confirm-refund',
          ),
          onPressed: () {
            final value =
            _controller.text.trim();

            if (value.isNotEmpty) {
              Navigator.pop(
                context,
                value,
              );
            }
          },
          child: const Text(
            '전액 환불 확정',
          ),
        ),
      ],
    );
  }
}