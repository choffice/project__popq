import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/customer_realtime_scope.dart';
import '../../routing/customer_router.dart';
import '../inquiry/customer_order_message_repository.dart';
import 'customer_order_repository.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    required this.orderPublicId,
    required this.repository,
    required this.messageRepository,
    super.key,
  });

  final String orderPublicId;
  final CustomerOrderRepository repository;
  final CustomerOrderMessageRepository messageRepository;

  @override
  State<OrderDetailScreen> createState() {
    return _OrderDetailScreenState();
  }
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  static const Duration _fallbackPollingInterval = Duration(
    seconds: 3,
  );

  CustomerOrder? _order;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _customerChatSubscription;
  PopqRealtimeSubscription? _customerOrderSubscription;
  Timer? _fallbackPollingTimer;

  Object? _error;

  var _unreadCount = 0;
  var _loading = true;
  var _syncing = false;
  var _unreadRequestInProgress = false;
  var _requestGeneration = 0;
  var _observedConnectionEpoch = 0;
  var _isAppActive = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed;

    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextRealtimeClient =
        CustomerRealtimeScope.of(context);

    if (identical(_realtimeClient, nextRealtimeClient)) {
      return;
    }

    _customerChatSubscription?.cancel();
    _customerChatSubscription = null;

    _customerOrderSubscription?.cancel();
    _customerOrderSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    _realtimeClient = nextRealtimeClient;
    _observedConnectionEpoch =
        nextRealtimeClient.connectionEpoch;

    nextRealtimeClient.addListener(
      _handleRealtimeClientChanged,
    );

    _customerChatSubscription =
        nextRealtimeClient.subscribeToCustomerChat(
      onEvent: _handleCustomerChatEvent,
      onError: _handleCustomerChatError,
    );

    _customerOrderSubscription =
        nextRealtimeClient.subscribeToCustomerOrders(
      onEvent: _handleCustomerOrderEvent,
      onError: _handleCustomerOrderError,
    );

    _syncFallbackPollingWithRealtime();
  }

  @override
  void didUpdateWidget(
      covariant OrderDetailScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.orderPublicId != widget.orderPublicId ||
        oldWidget.repository != widget.repository ||
        oldWidget.messageRepository !=
            widget.messageRepository) {
      _requestGeneration++;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _syncFallbackPollingWithRealtime();

        unawaited(
          _recoverLatestState(),
        );

        return;

      case AppLifecycleState.inactive:
        _isAppActive = false;
        _stopFallbackPolling();
        return;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isAppActive = false;
        _stopFallbackPolling();
        return;
    }
  }

  @override
  void dispose() {
    _requestGeneration++;

    WidgetsBinding.instance.removeObserver(this);

    _stopFallbackPolling();

    _customerChatSubscription?.cancel();
    _customerChatSubscription = null;

    _customerOrderSubscription?.cancel();
    _customerOrderSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );
    _realtimeClient = null;

    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go(CustomerRoutes.orders);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (
        bool didPop,
        Object? result,
      ) {
        if (didPop) {
          return;
        }

        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: '뒤로가기',
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
          ),
          title: const Text('주문 상세'),
        ),
        body: _buildBody(),
      ),
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
        message: '주문 상세를 불러오지 못했습니다.',
        onRetry: _load,
      );
    }

    final order = _order!;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(
          PopqSpacing.lg,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(
              PopqSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: PopqPalette.forest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: PopqPalette.lime,
                  size: 48,
                ),
                const SizedBox(
                  height: PopqSpacing.sm,
                ),
                Text(
                  _statusLabel(order.status),
                  textAlign: TextAlign.center,
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
                  order.storeName,
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: PopqSpacing.lg,
          ),

          _OrderNumberSection(
            orderPublicId: order.orderPublicId,
          ),

          if (order.preparationMinutes != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(
                  order.preparationMinutes == 0
                      ? '상품을 바로 준비해요'
                      : '예상 준비시간 ${order.preparationMinutes}분',
                ),
                subtitle: order.estimatedReadyAt == null
                    ? null
                    : Text(
                        '예상 완료 ${_formatEstimatedTime(order.estimatedReadyAt!)}',
                      ),
              ),
            ),
          ],

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          Text(
            '주문 상품',
            style:
            Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
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
                '${item.quantity}개',
              ),
              trailing: Text(
                _won(item.itemTotalPrice),
              ),
            ),

          const Divider(),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '총 결제 금액',
            ),
            trailing: Text(
              _won(order.totalAmount),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          _InquirySection(
            unreadCount: _unreadCount,
            onPressed: _openInquiry,
          ),

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          if (order.status == 'COMPLETED') ...[
            FilledButton.icon(
              onPressed: () async {
                final created =
                await context.push<bool>(
                  '${CustomerRoutes.orders}/'
                      '${order.orderPublicId}/review',
                );

                if (!mounted) {
                  return;
                }

                if (created == true) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        '리뷰를 등록했어요.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.rate_review_rounded,
              ),
              label: const Text(
                '리뷰 작성',
              ),
            ),
            const SizedBox(
              height: PopqSpacing.sm,
            ),
          ],

          OutlinedButton.icon(
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.sync_rounded,
            ),
            label: Text(
              _syncing
                  ? '확인 중...'
                  : '최신 상태 확인',
            ),
          ),

          const SizedBox(
            height: PopqSpacing.sm,
          ),

          Text(
            '서버 버전 ${order.version} · '
                '알림 수신 후에도 이 API로 최신 상태를 '
                '다시 확인합니다.',
            textAlign: TextAlign.center,
            style:
            Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatEstimatedTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day} $hour:$minute';
  }

  Future<void> _load() async {
    final generation = ++_requestGeneration;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final order = await widget.repository.findOne(
        widget.orderPublicId,
      );

      final unreadCount =
          await _findUnreadCount();

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );
        _unreadCount = unreadCount ?? 0;
        _loading = false;
        _error = null;
      });
    } catch (caught) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _error = caught;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final generation = _requestGeneration;

    try {
      final order = await widget.repository.findOne(
        widget.orderPublicId,
      );

      final unreadCount =
          await _findUnreadCount();

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );

        if (unreadCount != null) {
          _unreadCount = unreadCount;
        }

        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '최신 주문 정보를 불러오지 못했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _refreshOrderSilently() async {
    final generation = _requestGeneration;

    try {
      final order = await widget.repository.findOne(
        widget.orderPublicId,
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );
        _error = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '주문 상세 최신 상태를 자동 복구하지 못했습니다: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _syncOrderAfterRealtimeEvent({
    required int knownVersion,
  }) async {
    final generation = _requestGeneration;

    try {
      final result = await widget.repository.sync(
        widget.orderPublicId,
        knownVersion,
      );
      final serverOrder = result.order;

      if (!mounted ||
          generation != _requestGeneration ||
          serverOrder == null) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: serverOrder,
        );
        _error = null;
      });
    } catch (error, stackTrace) {
      // status/version은 실시간 이벤트에서 이미 반영했습니다.
      // 준비시간 같은 나머지 필드는 재연결/fallback REST 조회에서
      // 다시 복구합니다.
      debugPrint(
        '주문 상세 실시간 이벤트 후 REST 동기화에 실패했습니다: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _recoverLatestState() async {
    await Future.wait<void>(<Future<void>>[
      _refreshOrderSilently(),
      _refreshUnreadCount(),
    ]);
  }

  Future<void> _sync() async {
    final current = _order;

    if (current == null || _syncing) {
      return;
    }

    setState(() {
      _syncing = true;
    });

    try {
      final result = await widget.repository.sync(
        current.orderPublicId,
        current.version,
      );

      final unreadCount =
      await _findUnreadCount();

      if (!mounted) {
        return;
      }

      setState(() {
        if (result.order != null) {
          _order = _newerOrder(
            current: _order,
            candidate: result.order!,
          );
        }

        if (unreadCount != null) {
          _unreadCount = unreadCount;
        }

        _syncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.refreshRequired
                ? '최신 주문 상태로 갱신했습니다.'
                : '이미 최신 상태입니다.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _syncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '최신 상태를 확인하지 못했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _openInquiry() async {
    final order = _order;

    if (order == null) {
      return;
    }

    await context.push(
      CustomerRoutes.orderMessages(
        order.orderPublicId,
      ),
    );

    if (!mounted) {
      return;
    }

    /*
     * 채팅 화면에서 판매자 답변을 조회하면
     * 백엔드가 해당 메시지를 읽음 처리합니다.
     *
     * 화면 복귀 즉시 배지를 제거한 뒤
     * 서버의 최신 주문 및 읽지 않은 개수를 다시 확인합니다.
     */
    setState(() {
      _unreadCount = 0;
    });

    await _refreshAfterInquiry();
  }

  Future<void> _refreshAfterInquiry() async {
    try {
      final order = await widget.repository.findOne(
        widget.orderPublicId,
      );

      final unreadCount =
      await _findUnreadCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );
        _unreadCount = unreadCount ?? 0;
        _error = null;
      });
    } catch (_) {
      /*
       * 채팅 화면에서 정상적으로 돌아온 경우에는
       * 주문 상세 화면을 오류 화면으로 바꾸지 않습니다.
       */
    }
  }

  Future<int?> _findUnreadCount() async {
    try {
      final counts = await widget.messageRepository
          .findUnreadMessageCounts();

      for (final item in counts) {
        if (item.orderPublicId ==
            widget.orderPublicId) {
          return item.unreadCount;
        }
      }

      return 0;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshUnreadCount() async {
    if (!mounted || _unreadRequestInProgress) {
      return;
    }

    final generation = _requestGeneration;
    _unreadRequestInProgress = true;

    try {
      final unreadCount = await _findUnreadCount();

      if (!mounted ||
          generation != _requestGeneration ||
          unreadCount == null ||
          unreadCount == _unreadCount) {
        return;
      }

      setState(() {
        _unreadCount = unreadCount;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '주문 상세의 읽지 않은 답변 수를 갱신하지 못했습니다: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _unreadRequestInProgress = false;
    }
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) {
      return;
    }

    final realtimeClient = _realtimeClient;

    if (realtimeClient == null) {
      return;
    }

    if (_observedConnectionEpoch !=
        realtimeClient.connectionEpoch) {
      _observedConnectionEpoch =
          realtimeClient.connectionEpoch;

      // 재연결 직후 끊긴 동안 놓친 주문 상태와 문의 배지를
      // REST로 다시 조회합니다.
      unawaited(
        _recoverLatestState(),
      );
    }

    _syncFallbackPollingWithRealtime();
  }

  void _handleCustomerOrderEvent(
    PopqOrderRealtimeEvent event,
  ) {
    if (event.orderPublicId != widget.orderPublicId) {
      return;
    }

    final currentOrder = _order;

    if (currentOrder == null) {
      unawaited(
        _refreshOrderSilently(),
      );
      return;
    }

    if (event.isDuplicateOrOlderThan(currentOrder.version)) {
      return;
    }

    final knownVersion = currentOrder.version;

    setState(() {
      _order = currentOrder.applyRealtimeEvent(event);
      _error = null;
    });

    // 화면에는 즉시 상태를 보여주고, 이벤트에 포함되지 않은
    // 준비시간/예상완료시간 등은 REST sync로 보정합니다.
    unawaited(
      _syncOrderAfterRealtimeEvent(
        knownVersion: knownVersion,
      ),
    );
  }

  void _handleCustomerOrderError(
    Object error,
  ) {
    debugPrint(
      '주문 상세 실시간 상태 이벤트를 처리하지 못했습니다: $error',
    );
  }

  void _handleCustomerChatEvent(
    PopqRealtimeEvent event,
  ) {
    if (event.orderPublicId != widget.orderPublicId) {
      return;
    }

    final shouldRefresh =
        event.isMessageRead ||
        (event.isMessageCreated &&
            event.message?.sentBySeller == true);

    if (!shouldRefresh) {
      return;
    }

    unawaited(
      _refreshUnreadCount(),
    );
  }

  void _handleCustomerChatError(
    Object error,
  ) {
    debugPrint(
      '주문 상세 실시간 채팅 이벤트를 처리하지 못했습니다: $error',
    );
  }

  void _syncFallbackPollingWithRealtime() {
    if (!_isAppActive) {
      _stopFallbackPolling();
      return;
    }

    if (_realtimeClient?.isConnected == true) {
      _stopFallbackPolling();
      return;
    }

    _startFallbackPolling();
  }

  void _startFallbackPolling() {
    if (!_isAppActive ||
        _realtimeClient?.isConnected == true ||
        (_fallbackPollingTimer?.isActive ?? false)) {
      return;
    }

    _fallbackPollingTimer = Timer.periodic(
      _fallbackPollingInterval,
      (_) {
        unawaited(
          _recoverLatestState(),
        );
      },
    );
  }

  void _stopFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;
  }
  CustomerOrder _newerOrder({
    required CustomerOrder? current,
    required CustomerOrder candidate,
  }) {
    if (current != null && current.version > candidate.version) {
      return current;
    }

    return candidate;
  }
}

class _OrderNumberSection extends StatelessWidget {
  const _OrderNumberSection({
    required this.orderPublicId,
  });

  final String orderPublicId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '주문번호',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.xs,
          ),
          SelectableText(
            formatPopqOrderNumber(orderPublicId),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InquirySection extends StatelessWidget {
  const _InquirySection({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasUnreadMessage = unreadCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasUnreadMessage
              ? colorScheme.error
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasUnreadMessage
                    ? Icons.mark_chat_unread_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: hasUnreadMessage
                    ? colorScheme.error
                    : colorScheme.primary,
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              Expanded(
                child: Text(
                  '1:1 문의',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasUnreadMessage)
                _UnreadCountBadge(
                  unreadCount: unreadCount,
                ),
            ],
          ),
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          Text(
            hasUnreadMessage
                ? '매장에서 보낸 새 답변이 있어요.'
                : '주문이나 상품에 궁금한 점을 매장에 문의해 보세요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasUnreadMessage
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              fontWeight: hasUnreadMessage
                  ? FontWeight.w700
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.md,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(
                Icons.chat_rounded,
              ),
              label: Text(
                hasUnreadMessage
                    ? '새 답변 확인하기'
                    : '문의하기',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({
    required this.unreadCount,
  });

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minWidth: 24,
        minHeight: 24,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        unreadCount > 99
            ? '99+'
            : unreadCount.toString(),
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'CREATED' => '결제 대기',
    'PLACED' => '주문 접수 대기',
    'ACCEPTED' => '주문이 접수됐어요',
    'PREPARING' => '상품을 준비하고 있어요',
    'READY' => '준비가 완료됐어요',
    'COMPLETED' => '주문 완료',
    'REJECTED' => '주문 거절',
    'CANCELED' => '주문 취소',
    'EXPIRED' => '결제 만료',
    _ => status,
  };
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0;
  index < digits.length;
  index++) {
    if (index > 0 &&
        (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return '$buffer원';
}
