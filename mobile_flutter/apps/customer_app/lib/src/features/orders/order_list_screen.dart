import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/customer_realtime_scope.dart';
import '../../routing/customer_router.dart';
import '../inquiry/customer_order_message_repository.dart';
import 'customer_order_repository.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({
    required this.repository,
    required this.messageRepository,
    super.key,
  });

  final CustomerOrderRepository repository;
  final CustomerOrderMessageRepository messageRepository;

  @override
  State<OrderListScreen> createState() {
    return _OrderListScreenState();
  }
}

class _OrderListScreenState extends State<OrderListScreen>
    with WidgetsBindingObserver {
  static const Duration _fallbackPollingInterval = Duration(
    seconds: 3,
  );

  _OrderListData? _data;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _customerChatSubscription;
  Timer? _fallbackPollingTimer;

  var _initialLoading = true;
  var _unreadRefreshInProgress = false;
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

    unawaited(
      _loadAll(showLoading: true),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextRealtimeClient = CustomerRealtimeScope.of(context);

    if (identical(_realtimeClient, nextRealtimeClient)) {
      return;
    }

    _customerChatSubscription?.cancel();
    _customerChatSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    _realtimeClient = nextRealtimeClient;
    _observedConnectionEpoch = nextRealtimeClient.connectionEpoch;

    nextRealtimeClient.addListener(
      _handleRealtimeClientChanged,
    );

    _customerChatSubscription =
        nextRealtimeClient.subscribeToCustomerChat(
      onEvent: _handleCustomerChatEvent,
      onError: _handleCustomerChatError,
    );

    _syncFallbackPollingWithRealtime();
  }

  @override
  void didUpdateWidget(
    covariant OrderListScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.repository != widget.repository ||
        oldWidget.messageRepository != widget.messageRepository) {
      unawaited(
        _loadAll(showLoading: true),
      );
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
          _refreshUnreadCounts(),
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

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );
    _realtimeClient = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading && _data == null) {
      return const PopqLoadingView(
        message: '주문 내역을 불러오고 있어요.',
      );
    }

    final data = _data;

    if (data == null) {
      return PopqErrorView(
        message: '주문 내역을 불러오지 못했습니다.',
        onRetry: () {
          unawaited(
            _loadAll(showLoading: true),
          );
        },
      );
    }

    if (data.orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: const CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: PopqEmptyView(
                icon: Icons.receipt_long_outlined,
                title: '아직 주문 내역이 없어요.',
                description:
                    '마음에 드는 스토어에서 첫 주문을 시작해 보세요.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(
          PopqSpacing.md,
        ),
        itemCount: data.orders.length,
        separatorBuilder: (_, _) {
          return const SizedBox(
            height: PopqSpacing.sm,
          );
        },
        itemBuilder: (BuildContext context, int index) {
          final order = data.orders[index];

          final unreadCount =
              data.unreadCounts[order.orderPublicId] ?? 0;

          return _OrderCard(
            order: order,
            unreadCount: unreadCount,
            onOpenDetail: () {
              _openOrderDetail(order);
            },
            onOpenInquiry: () {
              _openOrderInquiry(order);
            },
          );
        },
      ),
    );
  }

  Future<void> _loadAll({
    required bool showLoading,
  }) async {
    final generation = ++_requestGeneration;

    if (showLoading && mounted) {
      setState(() {
        _initialLoading = true;
      });
    }

    try {
      final ordersFuture = widget.repository.findAll();
      final unreadCountsFuture =
          widget.messageRepository.findUnreadMessageCounts();

      final orders = await ordersFuture;
      final unreadCounts = await unreadCountsFuture;

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _data = _OrderListData(
          orders: orders,
          unreadCounts: <String, int>{
            for (final item in unreadCounts)
              item.orderPublicId: item.unreadCount,
          },
        );
        _initialLoading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      debugPrint(
        '구매자 주문 내역을 불러오지 못했습니다: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      setState(() {
        _initialLoading = false;
      });
    }
  }

  Future<void> _refreshUnreadCounts() async {
    if (!mounted || _unreadRefreshInProgress) {
      return;
    }

    if (_data == null) {
      await _loadAll(showLoading: false);
      return;
    }

    final generation = _requestGeneration;
    _unreadRefreshInProgress = true;

    try {
      final unreadCounts = await widget.messageRepository
          .findUnreadMessageCounts();

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      final nextUnreadCounts = <String, int>{
        for (final item in unreadCounts)
          item.orderPublicId: item.unreadCount,
      };

      if (_sameUnreadCounts(
        _data!.unreadCounts,
        nextUnreadCounts,
      )) {
        return;
      }

      setState(() {
        _data = _data!.copyWith(
          unreadCounts: nextUnreadCounts,
        );
      });
    } catch (error, stackTrace) {
      // 자동 갱신 실패 시 기존 화면은 유지하고 다음 이벤트 또는
      // fallback 폴링에서 다시 시도합니다.
      debugPrint(
        '주문별 읽지 않은 답변 수를 갱신하지 못했습니다: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _unreadRefreshInProgress = false;
    }
  }

  Future<void> _reload() {
    return _loadAll(showLoading: false);
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) {
      return;
    }

    final realtimeClient = _realtimeClient;

    if (realtimeClient == null) {
      return;
    }

    if (_observedConnectionEpoch != realtimeClient.connectionEpoch) {
      _observedConnectionEpoch = realtimeClient.connectionEpoch;

      // 재연결 직후 누락된 배지 변화를 REST로 한 번 복구합니다.
      unawaited(
        _refreshUnreadCounts(),
      );
    }

    _syncFallbackPollingWithRealtime();
  }

  void _handleCustomerChatEvent(
    PopqRealtimeEvent event,
  ) {
    final shouldRefresh =
        event.isMessageRead ||
        (event.isMessageCreated &&
            event.message?.sentBySeller == true);

    if (!shouldRefresh) {
      return;
    }

    unawaited(
      _refreshUnreadCounts(),
    );
  }

  void _handleCustomerChatError(
    Object error,
  ) {
    debugPrint(
      '주문 목록 실시간 채팅 이벤트를 처리하지 못했습니다: $error',
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
          _refreshUnreadCounts(),
        );
      },
    );
  }

  void _stopFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;
  }

  Future<void> _openOrderDetail(
    CustomerOrder order,
  ) async {
    await context.push(
      '${CustomerRoutes.orders}/${order.orderPublicId}',
    );

    if (!mounted) {
      return;
    }

    // 주문 상세 또는 상세에서 열린 문의 화면에서 돌아온 경우
    // 최신 주문 상태와 읽지 않은 답변 수를 다시 불러옵니다.
    await _reload();
  }

  Future<void> _openOrderInquiry(
    CustomerOrder order,
  ) async {
    await context.push(
      CustomerRoutes.orderMessages(
        order.orderPublicId,
      ),
    );

    if (!mounted) {
      return;
    }

    // 채팅 화면 진입 시 판매자 메시지가 읽음 처리되므로,
    // 화면 복귀 직후 읽지 않은 답변 배지를 다시 조회합니다.
    await _refreshUnreadCounts();
  }

  bool _sameUnreadCounts(
    Map<String, int> current,
    Map<String, int> next,
  ) {
    if (current.length != next.length) {
      return false;
    }

    for (final entry in current.entries) {
      if (next[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.unreadCount,
    required this.onOpenDetail,
    required this.onOpenInquiry,
  });

  final CustomerOrder order;
  final int unreadCount;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenInquiry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemSummary = formatPopqOrderItemSummary(
      order.items.map(
        (item) => '${item.productName} ${item.quantity}개',
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          // 기존 주문 카드 클릭 시 주문 상세로 이동하는 기능을 유지합니다.
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.md,
              PopqSpacing.md,
              PopqSpacing.sm,
            ),
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(
                Icons.receipt_long_rounded,
              ),
            ),
            title: Text(
              order.storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(
                top: PopqSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_statusLabel(order.status)),
                  const SizedBox(height: 2),
                  Text(
                    itemSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            isThreeLine: true,
            trailing: Text(
              _won(order.totalAmount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            onTap: onOpenDetail,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PopqSpacing.md,
            ),
            child: Divider(
              height: 1,
              color: colorScheme.outlineVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              PopqSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(
                      Icons.assignment_outlined,
                    ),
                    label: const Text(
                      '진행 현황 보기',
                    ),
                  ),
                ),
                const SizedBox(
                  width: PopqSpacing.sm,
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenInquiry,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _InquiryIcon(
                          unreadCount: unreadCount,
                        ),
                        const SizedBox(
                          width: PopqSpacing.sm,
                        ),
                        const Flexible(
                          child: Text(
                            '문의하기',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InquiryIcon extends StatelessWidget {
  const _InquiryIcon({
    required this.unreadCount,
  });

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: unreadCount > 0 ? 30 : 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned(
            left: 0,
            top: 2,
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  unreadCount > 99
                      ? '99+'
                      : unreadCount.toString(),
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderListData {
  const _OrderListData({
    required this.orders,
    required this.unreadCounts,
  });

  final List<CustomerOrder> orders;
  final Map<String, int> unreadCounts;

  _OrderListData copyWith({
    List<CustomerOrder>? orders,
    Map<String, int>? unreadCounts,
  }) {
    return _OrderListData(
      orders: orders ?? this.orders,
      unreadCounts: unreadCounts ?? this.unreadCounts,
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'CREATED' => '결제 대기',
    'PLACED' => '주문 접수 대기',
    'ACCEPTED' => '주문 접수',
    'PREPARING' => '준비 중',
    'READY' => '준비 완료',
    'COMPLETED' => '완료',
    'REJECTED' => '거절',
    'CANCELED' => '취소',
    'EXPIRED' => '만료',
    _ => status,
  };
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
