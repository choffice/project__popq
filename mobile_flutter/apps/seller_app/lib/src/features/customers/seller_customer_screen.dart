import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/seller_realtime_scope.dart';
import '../../routing/seller_router.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_customer_repository.dart';

class SellerCustomerScreen extends StatefulWidget {
  const SellerCustomerScreen({
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final SellerCustomerRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerCustomerScreen> createState() {
    return _SellerCustomerScreenState();
  }
}

class _SellerCustomerScreenState
    extends State<SellerCustomerScreen>
    with WidgetsBindingObserver {
  static const Duration _pollingInterval = Duration(
    seconds: 3,
  );

  static const int _maximumRememberedEventIds = 200;

  int? _loadedStoreId;
  int _requestSerial = 0;
  int _lastConnectionEpoch = 0;

  List<SellerConversationSummary>? _items;
  Object? _loadError;

  Timer? _pollingTimer;

  bool _requestInProgress = false;
  bool _isAppActive = true;

  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _storeChatSubscription;

  final Set<String> _rememberedEventIds = <String>{};
  final List<String> _rememberedEventIdOrder = <String>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed;

    widget.selectionController.addListener(
      _handleStoreSelectionChanged,
    );

    unawaited(
      _loadForCurrentStore(
        showLoading: true,
      ),
    );

    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextRealtimeClient = SellerRealtimeScope.maybeOf(
      context,
    );

    if (identical(_realtimeClient, nextRealtimeClient)) {
      return;
    }

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    _storeChatSubscription?.cancel();
    _storeChatSubscription = null;

    _realtimeClient = nextRealtimeClient;
    _lastConnectionEpoch =
        nextRealtimeClient?.connectionEpoch ?? 0;

    nextRealtimeClient?.addListener(
      _handleRealtimeClientChanged,
    );

    _subscribeToSelectedStore();
    _updatePollingForConnection();
  }

  @override
  void didUpdateWidget(
    covariant SellerCustomerScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectionController !=
        widget.selectionController) {
      oldWidget.selectionController.removeListener(
        _handleStoreSelectionChanged,
      );

      widget.selectionController.addListener(
        _handleStoreSelectionChanged,
      );

      _requestSerial++;
      _loadedStoreId = null;
      _items = null;
      _loadError = null;

      _subscribeToSelectedStore();

      unawaited(
        _loadForCurrentStore(
          showLoading: true,
        ),
      );

      _updatePollingForConnection();
      return;
    }

    if (oldWidget.repository != widget.repository) {
      _requestSerial++;
      _loadedStoreId = null;
      _items = null;
      _loadError = null;

      unawaited(
        _loadForCurrentStore(
          showLoading: true,
        ),
      );

      _updatePollingForConnection();
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
        _subscribeToSelectedStore();
        _updatePollingForConnection();

        unawaited(
          _refreshConversations(),
        );

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
  void dispose() {
    _requestSerial++;

    _stopPolling();

    _storeChatSubscription?.cancel();
    _storeChatSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    WidgetsBinding.instance.removeObserver(this);

    widget.selectionController.removeListener(
      _handleStoreSelectionChanged,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeId =
        widget.selectionController.selectedStoreId;

    if (storeId == null) {
      return const _NoSelectedStoreView();
    }

    final items = _items;

    if (items == null && _loadError == null) {
      return const PopqLoadingView(
        message: '고객 문의를 불러오고 있어요.',
      );
    }

    if (items == null && _loadError != null) {
      return PopqErrorView(
        message: '고객 문의 목록을 불러오지 못했어요.',
        onRetry: _reload,
      );
    }

    final conversations =
        items ?? const <SellerConversationSummary>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            PopqSpacing.lg,
            PopqSpacing.lg,
            PopqSpacing.lg,
            PopqSpacing.sm,
          ),
          child: Text(
            '고객 문의 목록',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: conversations.isEmpty
              ? RefreshIndicator(
                  onRefresh: _reload,
                  child: const CustomScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: PopqEmptyView(
                          icon: Icons.forum_outlined,
                          title: '도착한 고객 문의가 없어요.',
                          description:
                              '고객이 주문 문의를 보내면 '
                              '이곳에서 확인하고 답변할 수 있어요.',
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      PopqSpacing.lg,
                      PopqSpacing.sm,
                      PopqSpacing.lg,
                      PopqSpacing.xl,
                    ),
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) {
                      return const SizedBox(
                        height: PopqSpacing.sm,
                      );
                    },
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];

                      return _ConversationCard(
                        conversation: conversation,
                        onTap: () {
                          _openConversation(
                            conversation,
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _handleStoreSelectionChanged() {
    if (!mounted) {
      return;
    }

    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    if (_loadedStoreId == selectedStoreId) {
      return;
    }

    _requestSerial++;

    setState(() {
      _loadedStoreId = selectedStoreId;
      _items = null;
      _loadError = null;
    });

    _subscribeToSelectedStore();

    unawaited(
      _loadForCurrentStore(
        showLoading: true,
      ),
    );

    _updatePollingForConnection();
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) {
      return;
    }

    final realtimeClient = _realtimeClient;

    if (realtimeClient == null) {
      _updatePollingForConnection();
      return;
    }

    final connectionEpoch = realtimeClient.connectionEpoch;

    if (realtimeClient.isConnected &&
        connectionEpoch != _lastConnectionEpoch) {
      _lastConnectionEpoch = connectionEpoch;

      unawaited(
        _refreshConversations(),
      );
    }

    _updatePollingForConnection();
  }

  void _subscribeToSelectedStore() {
    _storeChatSubscription?.cancel();
    _storeChatSubscription = null;

    final realtimeClient = _realtimeClient;
    final storeId =
        widget.selectionController.selectedStoreId;

    if (realtimeClient == null || storeId == null) {
      return;
    }

    _storeChatSubscription = realtimeClient.subscribeToStoreChat(
      storeId: storeId,
      onEvent: _handleStoreChatEvent,
      onError: (error) {
        debugPrint(
          '판매자 고객 문의 목록 구독 오류: $error',
        );
      },
    );
  }

  void _handleStoreChatEvent(
    PopqRealtimeEvent event,
  ) {
    if (!mounted || !_rememberEvent(event.eventId)) {
      return;
    }

    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    if (selectedStoreId == null ||
        event.storeId != selectedStoreId) {
      return;
    }

    unawaited(
      _refreshConversations(),
    );
  }

  bool _rememberEvent(String eventId) {
    if (!_rememberedEventIds.add(eventId)) {
      return false;
    }

    _rememberedEventIdOrder.add(eventId);

    if (_rememberedEventIdOrder.length >
        _maximumRememberedEventIds) {
      final removedEventId =
          _rememberedEventIdOrder.removeAt(0);

      _rememberedEventIds.remove(removedEventId);
    }

    return true;
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
      (_) {
        unawaited(
          _refreshConversations(),
        );
      },
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadForCurrentStore({
    required bool showLoading,
  }) async {
    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    if (selectedStoreId == null) {
      return;
    }

    _loadedStoreId = selectedStoreId;

    await _fetchConversations(
      selectedStoreId,
      showLoading: showLoading,
    );
  }

  Future<void> _refreshConversations() async {
    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    if (selectedStoreId == null) {
      return;
    }

    await _fetchConversations(
      selectedStoreId,
      showLoading: false,
    );
  }

  Future<void> _fetchConversations(
    int storeId, {
    required bool showLoading,
  }) async {
    if (_requestInProgress) {
      return;
    }

    _requestInProgress = true;
    final requestSerial = ++_requestSerial;

    if (showLoading && mounted && _items == null) {
      setState(() {
        _loadError = null;
      });
    }

    try {
      final conversations =
          await widget.repository.findConversations(
        storeId,
      );

      if (!mounted ||
          requestSerial != _requestSerial ||
          widget.selectionController.selectedStoreId != storeId) {
        return;
      }

      final changed = !_sameConversationList(
        _items,
        conversations,
      );

      if (!changed && _loadError == null) {
        return;
      }

      setState(() {
        _loadedStoreId = storeId;
        _items = conversations;
        _loadError = null;
      });
    } catch (error, stackTrace) {
      if (!mounted ||
          requestSerial != _requestSerial ||
          widget.selectionController.selectedStoreId != storeId) {
        return;
      }

      if (_items == null) {
        setState(() {
          _loadError = error;
        });
      }

      debugPrint(
        '고객 문의 목록 갱신 실패: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _requestInProgress = false;
    }
  }

  bool _sameConversationList(
    List<SellerConversationSummary>? previous,
    List<SellerConversationSummary> next,
  ) {
    if (previous == null || previous.length != next.length) {
      return false;
    }

    for (var index = 0; index < previous.length; index++) {
      final left = previous[index];
      final right = next[index];

      if (left.orderPublicId != right.orderPublicId ||
          left.customerUserId != right.customerUserId ||
          left.customerName != right.customerName ||
          left.orderStatus != right.orderStatus ||
          left.lastMessage != right.lastMessage ||
          left.lastMessageSenderType != right.lastMessageSenderType ||
          left.lastMessageAt != right.lastMessageAt ||
          left.unreadCount != right.unreadCount) {
        return false;
      }
    }

    return true;
  }

  Future<void> _reload() async {
    await _refreshConversations();
  }

  Future<void> _openConversation(
    SellerConversationSummary conversation,
  ) async {
    final encodedOrderPublicId = Uri.encodeComponent(
      conversation.orderPublicId,
    );

    await context.push(
      '${SellerRoutes.customers}/$encodedOrderPublicId',
    );

    if (!mounted) {
      return;
    }

    await _refreshConversations();
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  final SellerConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasUnreadMessage = conversation.hasUnreadMessage;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: hasUnreadMessage ? 2 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(
            PopqSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Text(
                  _firstCharacter(
                    conversation.customerName,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(
                width: PopqSpacing.md,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            conversation.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: PopqSpacing.xs,
                        ),
                        Flexible(
                          child: Text(
                            formatPopqOrderNumber(
                              conversation.orderPublicId,
                              includeLabel: false,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: PopqSpacing.xs,
                    ),
                    Text(
                      conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasUnreadMessage
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: hasUnreadMessage
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _relativeTime(
                      conversation.lastMessageAt,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasUnreadMessage
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: hasUnreadMessage
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(
                    height: PopqSpacing.sm,
                  ),
                  AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    width: hasUnreadMessage ? 8 : 0,
                    height: hasUnreadMessage ? 8 : 0,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _firstCharacter(
    String value,
  ) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return '?';
    }

    return String.fromCharCode(
      normalized.runes.first,
    );
  }

  static String _relativeTime(
    DateTime value,
  ) {
    final localValue = value.toLocal();
    final now = DateTime.now();

    final difference = now.difference(localValue);

    if (difference.isNegative || difference.inMinutes < 1) {
      return '방금 전';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    }

    if (difference.inHours < 24 &&
        _isSameDay(now, localValue)) {
      return '${difference.inHours}시간 전';
    }

    if (_isSameDay(now, localValue)) {
      return '${_twoDigits(localValue.hour)}:'
          '${_twoDigits(localValue.minute)}';
    }

    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(
      const Duration(days: 1),
    );

    if (_isSameDay(yesterday, localValue)) {
      return '어제';
    }

    if (now.year == localValue.year) {
      return '${localValue.month}월 ${localValue.day}일';
    }

    return '${localValue.year}.'
        '${_twoDigits(localValue.month)}.'
        '${_twoDigits(localValue.day)}';
  }

  static bool _isSameDay(
    DateTime left,
    DateTime right,
  ) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String _twoDigits(
    int value,
  ) {
    return value.toString().padLeft(2, '0');
  }
}

class _NoSelectedStoreView extends StatelessWidget {
  const _NoSelectedStoreView();

  @override
  Widget build(BuildContext context) {
    return const PopqEmptyView(
      icon: Icons.storefront_outlined,
      title: '선택된 사업장이 없어요.',
      description:
          '대시보드에서 고객 문의를 확인할 사업장을 먼저 선택해 주세요.',
    );
  }
}
