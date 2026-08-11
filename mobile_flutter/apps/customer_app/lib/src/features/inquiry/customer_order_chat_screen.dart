import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../../realtime/customer_realtime_scope.dart';
import '../orders/customer_order_repository.dart';
import 'customer_order_message.dart';
import 'customer_order_message_repository.dart';
import '../../notifications/customer_app_badge_service.dart';
import '../notifications/customer_notification_repository.dart';

class CustomerOrderChatScreen extends StatefulWidget {
  const CustomerOrderChatScreen({
    required this.orderPublicId,
    required this.orderRepository,
    required this.messageRepository,
    required this.notificationRepository,
    super.key,
  });

  final String orderPublicId;
  final CustomerOrderRepository orderRepository;
  final CustomerOrderMessageRepository messageRepository;
  final CustomerNotificationRepository notificationRepository;

  @override
  State<CustomerOrderChatScreen> createState() {
    return _CustomerOrderChatScreenState();
  }
}

class _CustomerOrderChatScreenState extends State<CustomerOrderChatScreen>
    with WidgetsBindingObserver {
  static const Duration _pollingInterval = Duration(seconds: 3);
  static const Duration _draftConfirmationMatchWindow = Duration(minutes: 2);
  static const int _pageSize = 30;
  static const int _processedEventLimit = 200;
  static const double _olderMessageTriggerOffset = 80;

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<_OutgoingMessageDraft> _outgoingDrafts = [];
  final Set<String> _processedEventIds = <String>{};
  final List<String> _processedEventOrder = <String>[];

  CustomerOrder? _order;
  List<CustomerOrderMessage> _messages = const [];

  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _orderChatSubscription;

  int _nextDraftId = 0;
  int _requestGeneration = 0;
  int _lastHandledConnectionEpoch = 0;
  int _lastReadRequestMessageId = 0;
  int _pendingReadMessageId = 0;
  int? _nextBeforeMessageId;

  Future<void>? _readReceiptFuture;

  Object? _error;
  Timer? _pollingTimer;

  bool _isAppActive = true;
  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;
  bool _polling = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = false;
  bool _hasLoadedOlderPages = false;
  bool _pendingRealtimeSync = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);

    _isAppActive = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    unawaited(_loadConversation());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final realtimeClient = CustomerRealtimeScope.of(context);

    if (identical(_realtimeClient, realtimeClient)) {
      return;
    }

    _unbindRealtimeClient();
    _realtimeClient = realtimeClient;
    _realtimeClient!.addListener(_handleRealtimeChanged);
    _subscribeToCurrentOrder();
    _applyRealtimeState();
  }

  @override
  void didUpdateWidget(covariant CustomerOrderChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.orderPublicId != widget.orderPublicId ||
        oldWidget.orderRepository != widget.orderRepository ||
        oldWidget.messageRepository != widget.messageRepository) {
      _requestGeneration++;
      _orderChatSubscription?.cancel();
      _orderChatSubscription = null;

      _order = null;
      _messages = const [];
      _outgoingDrafts.clear();
      _processedEventIds.clear();
      _processedEventOrder.clear();
      _sending = false;
      _loadingOlder = false;
      _hasMoreOlder = false;
      _hasLoadedOlderPages = false;
      _pendingRealtimeSync = false;
      _lastHandledConnectionEpoch = 0;
      _lastReadRequestMessageId = 0;
      _pendingReadMessageId = 0;
      _readReceiptFuture = null;
      _nextBeforeMessageId = null;

      _subscribeToCurrentOrder();
      unawaited(_loadConversation());
      _applyRealtimeState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _applyRealtimeState(forcePoll: true);
        _markLatestSellerMessageAsRead();
        return;

      case AppLifecycleState.inactive:
        _isAppActive = false;
        _stopPolling();
        return;

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
    _requestGeneration++;
    _stopPolling();
    _unbindRealtimeClient();

    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_handleScroll);

    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        _markLatestSellerMessageAsRead();

        if (didPop) {
          return;
        }

        context.go(CustomerRoutes.profile);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_order?.storeName ?? '주문 문의'),
          actions: [
            IconButton(
              tooltip: '새로고침',
              onPressed: _loading || _sending || _refreshing || _loadingOlder
                  ? null
                  : _refreshConversation,
              icon: _refreshing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(
        message: '문의 내용을 불러오고 있어요.',
      );
    }

    if (_error != null || _order == null) {
      return PopqErrorView(
        message: '문의 내용을 불러오지 못했어요.',
        onRetry: _loadConversation,
      );
    }

    final Widget messageList = _messages.isEmpty && _outgoingDrafts.isEmpty
        ? const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: PopqEmptyView(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '아직 문의 내역이 없어요.',
                  description: '아래 입력창에서 매장에 궁금한 점을 남겨보세요.',
                ),
              ),
            ],
          )
        : _buildMessageList();

    return Column(
      children: [
        _OrderSummaryCard(order: _order!),
        Expanded(
          child: _hasMoreOlder || _loadingOlder
              ? messageList
              : RefreshIndicator(
                  onRefresh: _refreshConversation,
                  child: messageList,
                ),
        ),
        _MessageComposer(
          controller: _messageController,
          focusNode: _messageFocusNode,
          sending: _sending,
          onSend: _sendMessage,
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    final int leadingCount = _loadingOlder ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        PopqSpacing.md,
        PopqSpacing.md,
        PopqSpacing.md,
        PopqSpacing.lg,
      ),
      itemCount: leadingCount + _messages.length + _outgoingDrafts.length,
      itemBuilder: (context, index) {
        if (_loadingOlder && index == 0) {
          return const _OlderMessagesLoadingIndicator();
        }

        final int contentIndex = index - leadingCount;

        if (contentIndex < _messages.length) {
          final message = _messages[contentIndex];
          final previousMessage =
              contentIndex == 0 ? null : _messages[contentIndex - 1];
          final currentDate = message.createdAt.toLocal();
          final showDate = previousMessage == null ||
              !_isSameDay(
                previousMessage.createdAt.toLocal(),
                currentDate,
              );

          return Column(
            children: [
              if (showDate) _DateDivider(date: currentDate),
              _MessageBubble(message: message),
            ],
          );
        }

        final draftIndex = contentIndex - _messages.length;
        final draft = _outgoingDrafts[draftIndex];
        final previousDate = draftIndex > 0
            ? _outgoingDrafts[draftIndex - 1].createdAt
            : _messages.isEmpty
                ? null
                : _messages.last.createdAt;
        final currentDate = draft.createdAt.toLocal();
        final showDate = previousDate == null ||
            !_isSameDay(previousDate.toLocal(), currentDate);

        return Column(
          children: [
            if (showDate) _DateDivider(date: currentDate),
            _OutgoingMessageBubble(
              draft: draft,
              onRetry: _sending ? null : () => _retryMessage(draft.localId),
            ),
          ],
        );
      },
    );
  }

  void _subscribeToCurrentOrder() {
    final realtimeClient = _realtimeClient;

    if (realtimeClient == null || _orderChatSubscription != null) {
      return;
    }

    _orderChatSubscription = realtimeClient.subscribeToOrderChat(
      orderPublicId: widget.orderPublicId,
      onEvent: _handleRealtimeEvent,
      onError: (Object error) {
        debugPrint('고객 주문 문의 실시간 이벤트 처리 실패: $error');
      },
    );
  }

  void _unbindRealtimeClient() {
    _orderChatSubscription?.cancel();
    _orderChatSubscription = null;

    _realtimeClient?.removeListener(_handleRealtimeChanged);
    _realtimeClient = null;
  }

  void _handleRealtimeChanged() {
    if (!mounted) {
      return;
    }

    // 연결 상태 변경은 폴링 시작/중지만 제어합니다.
    // 연결 재시도 때마다 화면 전체를 다시 그리지 않아서
    // 채팅 화면이 위아래로 깜빡이지 않습니다.
    _applyRealtimeState();
  }

  void _applyRealtimeState({bool forcePoll = false}) {
    if (!mounted || !_isAppActive) {
      _stopPolling();
      return;
    }

    final realtimeClient = _realtimeClient;

    if (realtimeClient == null || realtimeClient.shouldUseRestFallback) {
      _startPolling();

      if (forcePoll) {
        unawaited(_pollConversation());
      }

      return;
    }

    _stopPolling();

    final connectionEpoch = realtimeClient.connectionEpoch;

    if (connectionEpoch <= 0 ||
        connectionEpoch == _lastHandledConnectionEpoch) {
      return;
    }

    _lastHandledConnectionEpoch = connectionEpoch;

    if (_loading || _refreshing) {
      _pendingRealtimeSync = true;
      return;
    }

    unawaited(_synchronizeAfterRealtimeConnection());
  }

  Future<void> _syncAppBadge() async {
    try {
      final badgeCount =
      await widget.notificationRepository.badgeCount();

      await CustomerAppBadgeService.updateBadge(
        badgeCount,
      );
    } catch (error, stackTrace) {
      debugPrint('앱 아이콘 배지 갱신 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _synchronizeAfterRealtimeConnection() async {
    if (!mounted ||
        !_isAppActive ||
        !(_realtimeClient?.isConnected ?? false)) {
      return;
    }

    _pendingRealtimeSync = false;
    await _synchronizeLatestPage(showError: false);
  }

  void _handleRealtimeEvent(PopqRealtimeEvent event) {
    if (!mounted ||
        event.orderPublicId != widget.orderPublicId ||
        !_rememberEvent(event.eventId)) {
      return;
    }

    switch (event.eventType) {
      case PopqRealtimeEventType.messageCreated:
        final realtimeMessage = event.message;

        if (realtimeMessage == null) {
          return;
        }

        final message = CustomerOrderMessage.fromRealtime(realtimeMessage);
        final shouldStickToBottom = _isNearBottom();

        setState(() {
          _removeConfirmedDrafts([message]);
          _messages = _mergeMessages(_messages, [message]);
          _error = null;
        });

        if (shouldStickToBottom) {
          _scrollToLatestMessage();
        }

        if (message.sentBySeller && _isChatActuallyVisible) {
          _markSellerMessageAsRead(message.orderMessageId);
        }

        return;

      case PopqRealtimeEventType.messageRead:
        if (event.readMessageIds.isEmpty) {
          return;
        }

        final readMessageIds = event.readMessageIds.toSet();
        final nextMessages = _messages
            .map(
              (message) => readMessageIds.contains(message.orderMessageId)
                  ? message.markAsRead(event.occurredAt)
                  : message,
            )
            .toList(growable: false);

        if (!_haveMessagesChanged(_messages, nextMessages)) {
          return;
        }

        setState(() {
          _messages = List<CustomerOrderMessage>.unmodifiable(nextMessages);
        });

        return;
    }
  }

  bool get _isChatActuallyVisible {
    return _isAppActive && (ModalRoute.of(context)?.isCurrent ?? false);
  }

  bool _rememberEvent(String eventId) {
    if (!_processedEventIds.add(eventId)) {
      return false;
    }

    _processedEventOrder.add(eventId);

    if (_processedEventOrder.length > _processedEventLimit) {
      final removedEventId = _processedEventOrder.removeAt(0);
      _processedEventIds.remove(removedEventId);
    }

    return true;
  }

  void _markSellerMessageAsRead(int orderMessageId) {
    if (orderMessageId <= _lastReadRequestMessageId) {
      return;
    }

    if (orderMessageId > _pendingReadMessageId) {
      _pendingReadMessageId = orderMessageId;
    }

    _readReceiptFuture ??= _flushReadReceipts().whenComplete(() {
      _readReceiptFuture = null;

      if (_pendingReadMessageId > _lastReadRequestMessageId) {
        _markSellerMessageAsRead(_pendingReadMessageId);
      }
    });
  }

  Future<void> _flushReadReceipts() async {
    while (_pendingReadMessageId > _lastReadRequestMessageId) {
      final targetMessageId = _pendingReadMessageId;

      try {
        await widget.messageRepository.markMessagesAsRead(
          orderPublicId: widget.orderPublicId,
          lastReadMessageId: targetMessageId,
        );

        _lastReadRequestMessageId = targetMessageId;
        await _syncAppBadge();
      } catch (error, stackTrace) {
        _pendingReadMessageId = _lastReadRequestMessageId;
        debugPrint('구매자 문의 읽음 처리 실패: $error');
        debugPrintStack(stackTrace: stackTrace);
        return;
      }
    }
  }

  void _markLatestSellerMessageAsRead() {
    if (!_isChatActuallyVisible) {
      return;
    }

    for (final message in _messages.reversed) {
      if (message.sentBySeller) {
        _markSellerMessageAsRead(message.orderMessageId);
        return;
      }
    }
  }



  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.pixels > _olderMessageTriggerOffset) {
      return;
    }

    unawaited(_loadOlderMessages());
  }

  Future<void> _loadConversation() async {
    final generation = _requestGeneration;

    setState(() {
      _loading = true;
      _refreshing = false;
      _loadingOlder = false;
      _error = null;
    });

    try {
      final orderFuture = widget.orderRepository.findOne(
        widget.orderPublicId,
      );
      final pageFuture = widget.messageRepository.findMessagePage(
        widget.orderPublicId,
        size: _pageSize,
      );

      final order = await orderFuture;
      final page = await pageFuture;

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = order;
        _removeConfirmedDrafts(page.messages);
        _messages = page.messages;
        _hasMoreOlder = page.hasMore;
        _nextBeforeMessageId = page.nextBeforeMessageId;
        _hasLoadedOlderPages = false;
        _loading = false;
        _error = null;
      });

      final realtimeClient = _realtimeClient;
      final shouldSynchronizeAgain = _pendingRealtimeSync;

      if (realtimeClient?.isConnected ?? false) {
        _lastHandledConnectionEpoch = realtimeClient!.connectionEpoch;
        _pendingRealtimeSync = false;
        _stopPolling();
      } else {
        _startPolling();
      }

      _scrollToLatestMessage(animate: false);
      _markLatestSellerMessageAsRead();

      if (shouldSynchronizeAgain &&
          (realtimeClient?.isConnected ?? false)) {
        unawaited(_synchronizeAfterRealtimeConnection());
      }
    } catch (error) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });

      _startPolling();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (!mounted ||
        _loading ||
        _refreshing ||
        _polling ||
        _loadingOlder ||
        !_hasMoreOlder) {
      return;
    }

    final int? beforeMessageId = _nextBeforeMessageId ??
        (_messages.isEmpty ? null : _messages.first.orderMessageId);

    if (beforeMessageId == null) {
      setState(() {
        _hasMoreOlder = false;
      });
      return;
    }

    final generation = _requestGeneration;
    final double previousMaxScrollExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0;
    final double previousOffset =
        _scrollController.hasClients ? _scrollController.position.pixels : 0;

    setState(() {
      _loadingOlder = true;
    });

    try {
      final page = await widget.messageRepository.findMessagePage(
        widget.orderPublicId,
        beforeMessageId: beforeMessageId,
        size: _pageSize,
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      final mergedMessages = _mergeMessages(
        page.messages,
        _messages,
      );

      setState(() {
        _removeConfirmedDrafts(page.messages);
        _messages = mergedMessages;
        _hasMoreOlder = page.hasMore;
        _nextBeforeMessageId = page.nextBeforeMessageId;
        _hasLoadedOlderPages = true;
        _loadingOlder = false;
      });

      _restoreScrollAfterPrepend(
        previousMaxScrollExtent: previousMaxScrollExtent,
        previousOffset: previousOffset,
      );
    } catch (_) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _loadingOlder = false;
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('이전 메시지를 불러오지 못했어요.'),
        ),
      );
    }
  }

  Future<void> _refreshConversation() {
    return _synchronizeLatestPage(showError: true);
  }

  Future<void> _synchronizeLatestPage({required bool showError}) async {
    if (_refreshing || _loading || _loadingOlder) {
      return;
    }

    final generation = _requestGeneration;
    final bool shouldStickToBottom = _isNearBottom();

    setState(() {
      _refreshing = true;
    });

    try {
      final orderFuture = widget.orderRepository.findOne(
        widget.orderPublicId,
      );
      final pageFuture = widget.messageRepository.findMessagePage(
        widget.orderPublicId,
        size: _pageSize,
      );

      final order = await orderFuture;
      final page = await pageFuture;

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      final bool hasNewMessage = _containsNewMessages(
        _messages,
        page.messages,
      );
      final nextMessages = _hasLoadedOlderPages
          ? _mergeMessages(_messages, page.messages)
          : page.messages;

      setState(() {
        _order = order;
        _removeConfirmedDrafts(page.messages);
        _messages = nextMessages;
        if (!_hasLoadedOlderPages) {
          _hasMoreOlder = page.hasMore;
          _nextBeforeMessageId = page.nextBeforeMessageId;
        }
        _error = null;
      });

      _markLatestSellerMessageAsRead();

      if (hasNewMessage && shouldStickToBottom) {
        _scrollToLatestMessage();
      }
    } catch (_) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }

      if (showError) {
        ScaffoldMessenger.of(context).showTopSnackBar(
          const SnackBar(
            content: Text('최신 문의 내용을 불러오지 못했어요.'),
          ),
        );
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _startPolling() {
    if (!_isAppActive ||
        !(_realtimeClient?.shouldUseRestFallback ?? true) ||
        (_pollingTimer?.isActive ?? false)) {
      return;
    }

    _pollingTimer = Timer.periodic(
      _pollingInterval,
      (_) => unawaited(_pollConversation()),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollConversation() async {
    if (!mounted ||
        !_isAppActive ||
        !(_realtimeClient?.shouldUseRestFallback ?? true) ||
        _loading ||
        _sending ||
        _refreshing ||
        _loadingOlder ||
        _polling) {
      return;
    }

    final generation = _requestGeneration;
    final bool shouldStickToBottom = _isNearBottom();
    _polling = true;

    try {
      final page = await widget.messageRepository.findMessagePage(
        widget.orderPublicId,
        size: _pageSize,
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      final bool hasNewMessage = _containsNewMessages(
        _messages,
        page.messages,
      );
      final nextMessages = _hasLoadedOlderPages
          ? _mergeMessages(_messages, page.messages)
          : page.messages;

      final draftsChanged = _containsConfirmedDraft(page.messages);

      if (!_haveMessagesChanged(_messages, nextMessages) && !draftsChanged) {
        return;
      }

      setState(() {
        _removeConfirmedDrafts(page.messages);
        _messages = nextMessages;
        if (!_hasLoadedOlderPages) {
          _hasMoreOlder = page.hasMore;
          _nextBeforeMessageId = page.nextBeforeMessageId;
        }
        _error = null;
      });

      _markLatestSellerMessageAsRead();

      if (hasNewMessage && shouldStickToBottom) {
        _scrollToLatestMessage();
      }
    } catch (error, stackTrace) {
      debugPrint('고객 주문 문의 REST fallback 갱신 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _polling = false;
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty || _sending) {
      return;
    }

    if (content.length > 2000) {
      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text('메시지는 2,000자 이하로 입력해 주세요.'),
        ),
      );
      return;
    }

    final draft = _OutgoingMessageDraft(
      localId: ++_nextDraftId,
      clientMessageId: PopqClientMessageId.generate(),
      content: content,
      createdAt: DateTime.now(),
      status: _OutgoingMessageStatus.sending,
    );

    setState(() {
      _sending = true;
      _outgoingDrafts.add(draft);
      _messageController.clear();
    });

    _scrollToLatestMessage();
    await _deliverDraft(draft.localId);
  }

  Future<void> _retryMessage(int localId) async {
    if (_sending) {
      return;
    }

    final draftIndex = _findDraftIndex(localId);

    if (draftIndex < 0) {
      return;
    }


    setState(() {
      _sending = true;
      _outgoingDrafts[draftIndex] =
          _outgoingDrafts[draftIndex].copyWith(
        status: _OutgoingMessageStatus.sending,
      );
    });

    await _deliverDraft(localId);
  }

  Future<void> _deliverDraft(int localId) async {
    // 현재 STOMP 연결이 서버에서 1002 코드로 종료될 수 있으므로,
    // 전송은 REST로 즉시 저장합니다.
    // WebSocket은 실시간 수신과 읽음 이벤트 처리에만 사용합니다.
    await _sendDraftByRest(
      localId,
      updateGlobalSending: true,
    );
  }

  Future<void> _sendDraftByRest(
    int localId, {
    required bool updateGlobalSending,
  }) async {
    final draftIndex = _findDraftIndex(localId);

    if (draftIndex < 0) {
      if (updateGlobalSending) {
        _setSending(false);
      }
      return;
    }

    final draft = _outgoingDrafts[draftIndex];
    final generation = _requestGeneration;
    final orderPublicId = widget.orderPublicId;

    try {
      final sentMessage = await widget.messageRepository.sendMessage(
        orderPublicId: orderPublicId,
        content: draft.content,
        clientMessageId: draft.clientMessageId,
      );

      if (!mounted ||
          generation != _requestGeneration ||
          widget.orderPublicId != orderPublicId) {
        return;
      }

      setState(() {
        _removeConfirmedDrafts([sentMessage]);
        _messages = _mergeMessages(_messages, [sentMessage]);
      });

      _scrollToLatestMessage();
      _messageFocusNode.requestFocus();
    } catch (_) {
      if (!mounted ||
          generation != _requestGeneration ||
          widget.orderPublicId != orderPublicId) {
        return;
      }

      final failedIndex = _findDraftIndex(localId);

      if (failedIndex < 0) {
        return;
      }

      setState(() {
        _outgoingDrafts[failedIndex] =
            _outgoingDrafts[failedIndex].copyWith(
          status: _OutgoingMessageStatus.failed,
        );
      });

      ScaffoldMessenger.of(context).showTopSnackBar(
        const SnackBar(
          content: Text(
            '메시지 전송에 실패했어요. 말풍선 아래 재전송을 눌러 주세요.',
          ),
        ),
      );
    } finally {
      if (updateGlobalSending &&
          mounted &&
          generation == _requestGeneration &&
          widget.orderPublicId == orderPublicId) {
        _setSending(false);
      }
    }
  }

  void _setSending(bool value) {
    if (!mounted || _sending == value) {
      return;
    }

    setState(() {
      _sending = value;
    });
  }

  int _findDraftIndex(int localId) {
    return _outgoingDrafts.indexWhere(
      (draft) => draft.localId == localId,
    );
  }

  bool _containsConfirmedDraft(
    List<CustomerOrderMessage> messages,
  ) {
    return messages.any(
      (message) => _outgoingDrafts.any(
        (draft) => _doesMessageConfirmDraft(
          message,
          draft,
        ),
      ),
    );
  }

  void _removeConfirmedDrafts(
    Iterable<CustomerOrderMessage> messages,
  ) {
    if (_outgoingDrafts.isEmpty) {
      return;
    }

    final confirmedLocalIds = <int>{};

    for (final message in messages) {
      final matchingDraft = _findMatchingDraft(
        message,
        excludedLocalIds: confirmedLocalIds,
      );

      if (matchingDraft == null) {
        continue;
      }

      confirmedLocalIds.add(
        matchingDraft.localId,
      );
    }

    if (confirmedLocalIds.isEmpty) {
      return;
    }


    _outgoingDrafts.removeWhere(
      (draft) => confirmedLocalIds.contains(
        draft.localId,
      ),
    );
  }

  _OutgoingMessageDraft? _findMatchingDraft(
    CustomerOrderMessage message, {
    required Set<int> excludedLocalIds,
  }) {
    final clientMessageId =
        message.clientMessageId?.trim();

    if (clientMessageId != null &&
        clientMessageId.isNotEmpty) {
      for (final draft in _outgoingDrafts) {
        if (excludedLocalIds.contains(
          draft.localId,
        )) {
          continue;
        }

        if (draft.clientMessageId ==
            clientMessageId) {
          return draft;
        }
      }
    }

    // 병합 과정에서 백엔드가 아직 clientMessageId를 내려주지 않는
    // 구버전 응답이 섞여도, 방금 보낸 구매자 메시지는 내용과 시각으로
    // 한 번만 임시 말풍선과 결합합니다.
    if (!message.sentByCustomer) {
      return null;
    }

    for (final draft in _outgoingDrafts) {
      if (excludedLocalIds.contains(
        draft.localId,
      )) {
        continue;
      }

      if (_doesMessageConfirmDraft(
        message,
        draft,
      )) {
        return draft;
      }
    }

    return null;
  }

  bool _doesMessageConfirmDraft(
    CustomerOrderMessage message,
    _OutgoingMessageDraft draft,
  ) {
    final clientMessageId =
        message.clientMessageId?.trim();

    if (clientMessageId != null &&
        clientMessageId.isNotEmpty) {
      return clientMessageId ==
          draft.clientMessageId;
    }

    if (!message.sentByCustomer ||
        message.content.trim() !=
            draft.content.trim()) {
      return false;
    }

    final difference = message.createdAt
        .toUtc()
        .difference(
          draft.createdAt.toUtc(),
        )
        .abs();

    return difference <=
        _draftConfirmationMatchWindow;
  }

  List<CustomerOrderMessage> _mergeMessages(
    List<CustomerOrderMessage> first,
    List<CustomerOrderMessage> second,
  ) {
    final messagesById = <int, CustomerOrderMessage>{};

    for (final message in first) {
      messagesById[message.orderMessageId] = message;
    }
    for (final message in second) {
      messagesById[message.orderMessageId] = message;
    }

    final messages = messagesById.values.toList()
      ..sort(
        (left, right) =>
            left.orderMessageId.compareTo(right.orderMessageId),
      );

    return List<CustomerOrderMessage>.unmodifiable(messages);
  }

  bool _containsNewMessages(
    List<CustomerOrderMessage> current,
    List<CustomerOrderMessage> incoming,
  ) {
    final currentIds =
        current.map((message) => message.orderMessageId).toSet();

    return incoming.any(
      (message) => !currentIds.contains(message.orderMessageId),
    );
  }

  bool _haveMessagesChanged(
    List<CustomerOrderMessage> previous,
    List<CustomerOrderMessage> next,
  ) {
    if (previous.length != next.length) {
      return true;
    }

    for (var index = 0; index < next.length; index++) {
      final previousMessage = previous[index];
      final nextMessage = next[index];

      if (previousMessage.orderMessageId != nextMessage.orderMessageId ||
          previousMessage.senderUserId != nextMessage.senderUserId ||
          previousMessage.senderName != nextMessage.senderName ||
          previousMessage.senderType != nextMessage.senderType ||
          previousMessage.clientMessageId != nextMessage.clientMessageId ||
          previousMessage.content != nextMessage.content ||
          previousMessage.read != nextMessage.read ||
          previousMessage.readAt != nextMessage.readAt ||
          previousMessage.createdAt != nextMessage.createdAt) {
        return true;
      }
    }

    return false;
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 120;
  }

  void _restoreScrollAfterPrepend({
    required double previousMaxScrollExtent,
    required double previousOffset,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      final addedExtent = position.maxScrollExtent - previousMaxScrollExtent;
      final target = (previousOffset + addedExtent).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );

      _scrollController.jumpTo(target.toDouble());
    });
  }

  void _scrollToLatestMessage({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final target = _scrollController.position.maxScrollExtent;

      if (!animate) {
        _scrollController.jumpTo(target);
        return;
      }

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _OlderMessagesLoadingIndicator extends StatelessWidget {
  const _OlderMessagesLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: PopqSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: PopqSpacing.sm),
          Text('이전 메시지를 불러오는 중...'),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.order,
  });

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        PopqSpacing.md,
        PopqSpacing.sm,
        PopqSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.storeName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: PopqSpacing.sm),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: PopqSpacing.sm),
          Text(
            '주문번호',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: PopqSpacing.xs),
          SelectableText(
            formatPopqOrderNumber(
              order.orderPublicId,
              includeLabel: false,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PopqSpacing.sm,
        vertical: PopqSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({
    required this.date,
  });

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PopqSpacing.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PopqSpacing.sm),
            child: Text(
              '${date.year}.${_twoDigits(date.month)}.${_twoDigits(date.day)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

enum _OutgoingMessageStatus {
  sending,
  failed,
}

class _OutgoingMessageDraft {
  const _OutgoingMessageDraft({
    required this.localId,
    required this.clientMessageId,
    required this.content,
    required this.createdAt,
    required this.status,
  });

  final int localId;
  final String clientMessageId;
  final String content;
  final DateTime createdAt;
  final _OutgoingMessageStatus status;

  _OutgoingMessageDraft copyWith({
    _OutgoingMessageStatus? status,
  }) {
    return _OutgoingMessageDraft(
      localId: localId,
      clientMessageId: clientMessageId,
      content: content,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}

class _OutgoingMessageBubble extends StatelessWidget {
  const _OutgoingMessageBubble({
    required this.draft,
    required this.onRetry,
  });

  final _OutgoingMessageDraft draft;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final failed = draft.status == _OutgoingMessageStatus.failed;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: PopqSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: PopqSpacing.xs),
                  child: Text(
                    '${_twoDigits(draft.createdAt.hour)}:'
                    '${_twoDigits(draft.createdAt.minute)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: PopqSpacing.md,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: failed
                          ? colorScheme.errorContainer
                          : colorScheme.primary,
                      border: failed
                          ? Border.all(color: colorScheme.error)
                          : null,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      draft.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: failed
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PopqSpacing.xs),
            if (failed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '전송 실패',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: PopqSpacing.xs),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 17,
                    ),
                    label: const Text('재전송'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: PopqSpacing.sm,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: PopqSpacing.xs),
                  Text(
                    '전송 중',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
  });

  final CustomerOrderMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sentByCustomer = message.sentByCustomer;
    final localCreatedAt = message.createdAt.toLocal();
    final bubbleColor = sentByCustomer
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final foregroundColor =
        sentByCustomer ? colorScheme.onPrimary : colorScheme.onSurface;

    return Align(
      alignment:
          sentByCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: PopqSpacing.sm),
        child: Column(
          crossAxisAlignment: sentByCustomer
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!sentByCustomer)
              Padding(
                padding: const EdgeInsets.only(
                  left: PopqSpacing.xs,
                  bottom: PopqSpacing.xs,
                ),
                child: Text(
                  message.senderName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (sentByCustomer)
                  Padding(
                    padding: const EdgeInsets.only(right: PopqSpacing.xs),
                    child: _MessageTime(
                      dateTime: localCreatedAt,
                      read: message.read,
                      showRead: true,
                    ),
                  ),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: PopqSpacing.md,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(sentByCustomer ? 20 : 6),
                        bottomRight: Radius.circular(sentByCustomer ? 6 : 20),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ),
                if (!sentByCustomer)
                  Padding(
                    padding: const EdgeInsets.only(left: PopqSpacing.xs),
                    child: _MessageTime(
                      dateTime: localCreatedAt,
                      read: message.read,
                      showRead: false,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageTime extends StatelessWidget {
  const _MessageTime({
    required this.dateTime,
    required this.read,
    required this.showRead,
  });

  final DateTime dateTime;
  final bool read;
  final bool showRead;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showRead)
          Text(
            read ? '읽음' : '전송됨',
            style: textStyle,
          ),
        Text(
          '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}',
          style: textStyle,
        ),
      ],
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PopqSpacing.md,
            PopqSpacing.sm,
            PopqSpacing.md,
            PopqSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: '매장에 문의할 내용을 입력하세요.',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: PopqSpacing.md,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PopqSpacing.sm),
              IconButton.filled(
                tooltip: '메시지 전송',
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'CREATED' => '결제 대기',
    'PLACED' => '접수 대기',
    'ACCEPTED' => '주문 접수',
    'PREPARING' => '준비 중',
    'READY' => '준비 완료',
    'COMPLETED' => '주문 완료',
    'REJECTED' => '주문 거절',
    'CANCELED' => '주문 취소',
    'EXPIRED' => '결제 만료',
    _ => status,
  };
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
