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
  CustomerPaymentSummary? _paymentSummary;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _customerChatSubscription;
  PopqRealtimeSubscription? _customerOrderSubscription;
  Timer? _fallbackPollingTimer;

  Object? _error;

  var _unreadCount = 0;
  var _loading = true;
  var _syncing = false;
  var _canceling = false;
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
    context.go(CustomerRoutes.orders);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
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

          if (_latestCancellationHistory(order) case final history?) ...[
            const SizedBox(height: PopqSpacing.sm),
            _CancellationInfoSection(
              orderStatus: order.status,
              history: history,
            ),
          ],

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

          if (_paymentSummary case final payment?) ...[
            const SizedBox(height: PopqSpacing.md),
            _PaymentRefundSection(
              payment: payment,
            ),
          ],

          const SizedBox(
            height: PopqSpacing.lg,
          ),

          _InquirySection(
            unreadCount: _unreadCount,
            onPressed: _openInquiry,
          ),

          if (order.status == 'PLACED') ...[
            const SizedBox(
              height: PopqSpacing.lg,
            ),
            _CustomerCancelSection(
              canceling: _canceling,
              onPressed: _cancelOrder,
            ),
          ],

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
                      .showTopSnackBar(
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
      final unreadCount = await _findUnreadCount();
      final paymentSummary = await _findPaymentSummary(order);

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );
        _paymentSummary = paymentSummary;
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
      final unreadCount = await _findUnreadCount();
      final paymentSummary = await _findPaymentSummary(order);

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: order,
        );

        if (paymentSummary != null) {
          _paymentSummary = paymentSummary;
        }

        if (unreadCount != null) {
          _unreadCount = unreadCount;
        }

        _error = null;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      ScaffoldMessenger.of(context).showTopSnackBar(
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

      await _refreshPaymentSummary();
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
      _refreshPaymentSummary(),
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
      final syncOrder = result.order ?? current;
      final paymentSummary = await _findPaymentSummary(syncOrder);

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

        if (paymentSummary != null) {
          _paymentSummary = paymentSummary;
        }

        if (unreadCount != null) {
          _unreadCount = unreadCount;
        }

        _syncing = false;
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
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

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            '최신 상태를 확인하지 못했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final order = _order;

    if (order == null ||
        order.status != 'PLACED' ||
        _canceling) {
      return;
    }

    final reason = await _showCancelReasonSheet();

    if (!mounted || reason == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('주문을 취소하시겠어요?'),
          content: Text(
            '취소 사유: $reason\n\n'
            '판매자가 아직 접수하지 않은 주문만 취소할 수 있으며, '
            '취소가 완료되면 결제 금액도 전액 환불 처리됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('돌아가기'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('주문 취소'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _canceling = true;
    });

    try {
      final canceled = await widget.repository.cancel(
        order.orderPublicId,
        reason: reason,
      );
      final paymentSummary = await _findPaymentSummary(canceled);

      if (!mounted) {
        return;
      }

      setState(() {
        _order = _newerOrder(
          current: _order,
          candidate: canceled,
        );

        if (paymentSummary != null) {
          _paymentSummary = paymentSummary;
        }

        _canceling = false;
        _error = null;
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            '주문을 취소했고 결제 금액도 환불 처리했어요.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('고객 주문 취소에 실패했습니다: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _canceling = false;
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            '주문을 취소하지 못했습니다. 판매자가 이미 접수했거나 환불 처리에 실패했을 수 있어요.',
          ),
        ),
      );

      await _refresh();
    }
  }

  Future<String?> _showCancelReasonSheet() async {
    const otherValue = '__OTHER__';
    const reasons = <String>[
      '주문을 잘못했어요',
      '다른 메뉴로 변경하고 싶어요',
      '기다리기 어려워요',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.lg,
              PopqSpacing.sm,
              PopqSpacing.lg,
              PopqSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '취소 사유를 선택해주세요',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: PopqSpacing.sm),
                Text(
                  '선택한 사유는 판매자에게도 표시됩니다.',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: PopqSpacing.md),
                for (final reason in reasons)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle_outlined),
                    title: Text(reason),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(reason),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('기타'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop(otherValue),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return null;
    }

    if (selected != otherValue) {
      return selected;
    }

    return _showCustomCancelReasonDialog();
  }

  Future<String?> _showCustomCancelReasonDialog() async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('취소 사유 입력'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 100,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '취소 사유를 입력해주세요.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('닫기'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();

                  if (value.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('선택'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
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

  Future<CustomerPaymentSummary?> _findPaymentSummary(
    CustomerOrder order,
  ) async {
    if (order.status == 'CREATED') {
      return null;
    }

    try {
      return await widget.repository.findPaymentSummary(
        order.orderPublicId,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '주문 상세 결제/환불 정보를 불러오지 못했습니다: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _refreshPaymentSummary() async {
    final order = _order;

    if (!mounted || order == null) {
      return;
    }

    final generation = _requestGeneration;
    final paymentSummary = await _findPaymentSummary(order);

    if (!mounted ||
        generation != _requestGeneration ||
        paymentSummary == null) {
      return;
    }

    setState(() {
      _paymentSummary = paymentSummary;
    });
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

CustomerOrderStatusHistory? _latestCancellationHistory(
  CustomerOrder order,
) {
  for (final history in order.statusHistory.reversed) {
    if (history.isCancellationOrRejection) {
      return history;
    }
  }

  return null;
}

class _CancellationInfoSection extends StatelessWidget {
  const _CancellationInfoSection({
    required this.orderStatus,
    required this.history,
  });

  final String orderStatus;
  final CustomerOrderStatusHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRejected = orderStatus == 'REJECTED';
    final reason = history.reason?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejected
                    ? Icons.block_rounded
                    : Icons.cancel_outlined,
                color: colorScheme.error,
              ),
              const SizedBox(width: PopqSpacing.sm),
              Text(
                isRejected ? '주문 거절 정보' : '주문 취소 정보',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.md),
          _InfoRow(
            label: isRejected ? '거절 주체' : '취소 주체',
            value: _actorLabel(history.actorType),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: isRejected ? '거절 사유' : '취소 사유',
            value: reason == null || reason.isEmpty
                ? '사유가 등록되지 않았어요.'
                : reason,
            alignTop: true,
          ),
          if (history.changedAt != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: isRejected ? '거절 시간' : '취소 시간',
              value: _formatDateTime(history.changedAt!),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentRefundSection extends StatelessWidget {
  const _PaymentRefundSection({
    required this.payment,
  });

  final CustomerPaymentSummary payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: PopqSpacing.sm),
              Text(
                '결제·환불',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.md),
          _InfoRow(
            label: '결제 상태',
            value: _paymentStatusLabel(payment.paymentStatus),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '결제 수단',
            value: _paymentMethodLabel(payment.paymentMethod),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '결제 금액',
            value: _won(payment.approvedAmount),
          ),
          if (payment.refundedAmount > 0) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '환불 금액',
              value: _won(payment.refundedAmount),
              valueStyle: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (payment.approvedAt != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '결제 승인',
              value: _formatDateTime(payment.approvedAt!),
            ),
          ],
          if (payment.canceledAt != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '결제 취소',
              value: _formatDateTime(payment.canceledAt!),
            ),
          ],
          if (payment.refunds.isNotEmpty) ...[
            const SizedBox(height: PopqSpacing.md),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: PopqSpacing.sm),
            Text(
              '환불 이력',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: PopqSpacing.sm),
            for (var index = 0; index < payment.refunds.length; index++) ...[
              _RefundHistoryCard(
                index: index + 1,
                refund: payment.refunds[index],
              ),
              if (index != payment.refunds.length - 1)
                const SizedBox(height: PopqSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _RefundHistoryCard extends StatelessWidget {
  const _RefundHistoryCard({
    required this.index,
    required this.refund,
  });

  final int index;
  final CustomerRefundHistory refund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reason = refund.reason.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '환불 $index',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _RefundStatusChip(status: refund.status),
            ],
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '환불 금액',
            value: _won(refund.amount),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '처리 주체',
            value: _actorLabel(refund.requesterType),
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '환불 사유',
            value: reason.isEmpty ? '사유가 등록되지 않았어요.' : reason,
            alignTop: true,
          ),
          const SizedBox(height: PopqSpacing.sm),
          _InfoRow(
            label: '요청 시간',
            value: _formatDateTime(refund.requestedAt),
          ),
          if (refund.completedAt != null) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '완료 시간',
              value: _formatDateTime(refund.completedAt!),
            ),
          ],
          if (refund.status == 'FAILED' &&
              (refund.failureMessage?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: PopqSpacing.sm),
            _InfoRow(
              label: '실패 사유',
              value: refund.failureMessage!.trim(),
              alignTop: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _RefundStatusChip extends StatelessWidget {
  const _RefundStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFailed = status == 'FAILED';
    final isSucceeded = status == 'SUCCEEDED';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isFailed
            ? colorScheme.errorContainer
            : isSucceeded
                ? colorScheme.primaryContainer
                : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _refundStatusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isFailed
              ? colorScheme.onErrorContainer
              : isSucceeded
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.alignTop = false,
    this.valueStyle,
  });

  final String label;
  final String value;
  final bool alignTop;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment:
          alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: PopqSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
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

class _CustomerCancelSection extends StatelessWidget {
  const _CustomerCancelSection({
    required this.canceling,
    required this.onPressed,
  });

  final bool canceling;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.error,
              ),
              const SizedBox(width: PopqSpacing.sm),
              Expanded(
                child: Text(
                  '주문 취소',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PopqSpacing.sm),
          Text(
            '판매자가 주문을 접수하기 전까지만 취소할 수 있어요. '
            '취소가 완료되면 결제 금액은 전액 환불됩니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PopqSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canceling ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
              ),
              icon: canceling
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.error,
                      ),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: Text(
                canceling ? '취소 처리 중...' : '주문 취소',
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

String _actorLabel(String actorType) {
  return switch (actorType) {
    'CUSTOMER' => '고객',
    'SELLER' => '판매자',
    'ADMIN' => '관리자',
    'SYSTEM' => '시스템',
    'GUEST' => '비회원 고객',
    _ => actorType,
  };
}

String _paymentStatusLabel(String status) {
  return switch (status) {
    'READY' => '결제 준비',
    'IN_PROGRESS' => '결제 확인 중',
    'PAID' => '결제 완료',
    'PARTIALLY_REFUNDED' => '부분 환불',
    'REFUNDED' => '환불 완료',
    'CANCELED' => '결제 취소',
    'FAILED' => '결제 실패',
    'EXPIRED' => '결제 만료',
    _ => status,
  };
}

String _paymentMethodLabel(String method) {
  return switch (method) {
    'CARD' => '카드 / 간편결제',
    'TEST' => '테스트 결제',
    _ => method,
  };
}

String _refundStatusLabel(String status) {
  return switch (status) {
    'REQUESTED' => '환불 요청',
    'PROCESSING' => '환불 처리 중',
    'SUCCEEDED' => '환불 완료',
    'FAILED' => '환불 실패',
    _ => status,
  };
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.year}.$month.$day $hour:$minute';
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
