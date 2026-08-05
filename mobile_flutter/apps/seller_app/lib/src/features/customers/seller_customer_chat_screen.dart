import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../realtime/seller_realtime_scope.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_customer_repository.dart';

class SellerCustomerChatScreen extends StatefulWidget {
  const SellerCustomerChatScreen({
    required this.orderPublicId,
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final String orderPublicId;
  final SellerCustomerRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerCustomerChatScreen> createState() {
    return _SellerCustomerChatScreenState();
  }
}

class _SellerCustomerChatScreenState
    extends State<SellerCustomerChatScreen>
    with WidgetsBindingObserver {
  static const Duration _pollingInterval = Duration(seconds: 3);
  static const Duration _serverConfirmationTimeout = Duration(
    seconds: 8,
  );
  static const int _pageSize = 30;
  static const int _maximumRememberedEventIds = 200;
  static const double _olderMessageTriggerOffset = 80;

  final TextEditingController _messageController =
      TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  SellerConversationDetail? _conversation;
  final List<_OutgoingMessageDraft> _outgoingDrafts = [];

  int _nextDraftId = 0;
  int _requestSerial = 0;
  int _lastConnectionEpoch = 0;
  int? _loadedStoreId;
  int? _nextBeforeMessageId;

  Object? _error;
  Timer? _pollingTimer;

  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _orderChatSubscription;

  final Set<String> _rememberedEventIds = <String>{};
  final List<String> _rememberedEventIdOrder = <String>[];
  final Map<String, Timer> _confirmationTimers = <String, Timer>{};

  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;
  bool _pollRequestInProgress = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = false;
  bool _hasLoadedOlderPages = false;
  bool _isAppActive = true;

  int? get _selectedStoreId {
    return widget.selectionController.selectedStoreId;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed;

    _scrollController.addListener(_handleScroll);
    widget.selectionController.addListener(
      _handleStoreSelectionChanged,
    );

    _loadConversation();
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

    _orderChatSubscription?.cancel();
    _orderChatSubscription = null;

    _realtimeClient = nextRealtimeClient;
    _lastConnectionEpoch =
        nextRealtimeClient?.connectionEpoch ?? 0;

    nextRealtimeClient?.addListener(
      _handleRealtimeClientChanged,
    );

    _subscribeToOrderChat();
    _updatePollingForConnection();
  }

  @override
  void didUpdateWidget(
    covariant SellerCustomerChatScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    var shouldReload = false;

    if (oldWidget.selectionController !=
        widget.selectionController) {
      oldWidget.selectionController.removeListener(
        _handleStoreSelectionChanged,
      );
      widget.selectionController.addListener(
        _handleStoreSelectionChanged,
      );
      shouldReload = true;
    }

    if (oldWidget.orderPublicId != widget.orderPublicId ||
        oldWidget.repository != widget.repository) {
      shouldReload = true;
    }

    if (shouldReload) {
      _requestSerial++;
      _resetConversationState();
      _subscribeToOrderChat();
      _loadConversation();
      _updatePollingForConnection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _subscribeToOrderChat();
        _updatePollingForConnection();
        unawaited(
          _pollConversation(force: true),
        );
        _markLatestCustomerMessageAsRead();
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
    _cancelAllConfirmationTimers();

    _orderChatSubscription?.cancel();
    _orderChatSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_handleScroll);
    widget.selectionController.removeListener(
      _handleStoreSelectionChanged,
    );

    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;

    return Scaffold(
      appBar: AppBar(
        title: Text(conversation?.customerName ?? '고객 문의'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ||
                    _sending ||
                    _refreshing ||
                    _loadingOlder
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
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PopqLoadingView(
        message: '고객 문의를 불러오고 있어요.',
      );
    }

    if (_error != null || _conversation == null) {
      return PopqErrorView(
        message: '고객 문의 내용을 불러오지 못했어요.',
        onRetry: _loadConversation,
      );
    }

    final conversation = _conversation!;
    final Widget messageList = conversation.messages.isEmpty &&
            _outgoingDrafts.isEmpty
        ? const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: PopqEmptyView(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '아직 대화가 없어요.',
                  description: '아래 입력창에서 고객에게 첫 답변을 보내 보세요.',
                ),
              ),
            ],
          )
        : _buildMessageList(conversation);

    return Column(
      children: [
        _OrderSummaryCard(conversation: conversation),
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

  Widget _buildMessageList(SellerConversationDetail conversation) {
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
      itemCount: leadingCount +
          conversation.messages.length +
          _outgoingDrafts.length,
      itemBuilder: (context, index) {
        if (_loadingOlder && index == 0) {
          return const _OlderMessagesLoadingIndicator();
        }

        final int contentIndex = index - leadingCount;

        if (contentIndex < conversation.messages.length) {
          final message = conversation.messages[contentIndex];
          final previousMessage = contentIndex == 0
              ? null
              : conversation.messages[contentIndex - 1];
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

        final draftIndex =
            contentIndex - conversation.messages.length;
        final draft = _outgoingDrafts[draftIndex];
        final previousDate = draftIndex > 0
            ? _outgoingDrafts[draftIndex - 1].createdAt
            : conversation.messages.isEmpty
                ? null
                : conversation.messages.last.createdAt;
        final currentDate = draft.createdAt.toLocal();
        final showDate = previousDate == null ||
            !_isSameDay(previousDate.toLocal(), currentDate);

        return Column(
          children: [
            if (showDate) _DateDivider(date: currentDate),
            _OutgoingMessageBubble(
              draft: draft,
              onRetry: _sending
                  ? null
                  : () => _retryMessage(draft.localId),
            ),
          ],
        );
      },
    );
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

    final nextConnectionEpoch = client.connectionEpoch;

    if (nextConnectionEpoch != _lastConnectionEpoch) {
      _lastConnectionEpoch = nextConnectionEpoch;
      _subscribeToOrderChat();

      if (nextConnectionEpoch > 0 && _isAppActive) {
        unawaited(
          _pollConversation(force: true),
        );
      }
    }

    _updatePollingForConnection();
  }

  void _subscribeToOrderChat() {
    _orderChatSubscription?.cancel();
    _orderChatSubscription = null;

    final client = _realtimeClient;
    final storeId = _selectedStoreId;

    if (client == null || storeId == null || !_isAppActive) {
      return;
    }

    _orderChatSubscription = client.subscribeToOrderChat(
      orderPublicId: widget.orderPublicId,
      onEvent: _handleRealtimeEvent,
      onError: (Object error) {
        debugPrint(
          '판매자 주문 채팅 구독 오류: $error',
        );
      },
    );
  }

  void _handleRealtimeEvent(PopqRealtimeEvent event) {
    if (!mounted ||
        event.orderPublicId != widget.orderPublicId ||
        event.storeId != _selectedStoreId ||
        !_rememberEventId(event.eventId)) {
      return;
    }

    switch (event.eventType) {
      case PopqRealtimeEventType.messageCreated:
        final realtimeMessage = event.message;

        if (realtimeMessage == null) {
          return;
        }

        final conversation = _conversation;
        if (conversation == null) {
          unawaited(
            _pollConversation(force: true),
          );
          return;
        }

        final message = SellerOrderMessage.fromRealtime(
          realtimeMessage,
        );
        final shouldStickToBottom = _isNearBottom();

        setState(() {
          _removeConfirmedDraftForMessage(message);
          _conversation = _withMessages(
            conversation,
            _mergeMessages(
              conversation.messages,
              <SellerOrderMessage>[message],
            ),
          );
          _sending = _outgoingDrafts.any(
            (draft) =>
                draft.status == _OutgoingMessageStatus.sending,
          );
          _error = null;
        });

        if (shouldStickToBottom) {
          _scrollToLatestMessage();
        }

        if (message.sentByCustomer) {
          _markLatestCustomerMessageAsRead();
        }

        return;

      case PopqRealtimeEventType.messageRead:
        if (event.readerType !=
                PopqRealtimeMessageSenderType.customer ||
            event.readMessageIds.isEmpty) {
          return;
        }

        final conversation = _conversation;
        if (conversation == null) {
          return;
        }

        final readIds = event.readMessageIds.toSet();
        var changed = false;

        final nextMessages = conversation.messages.map(
          (message) {
            if (!message.sentBySeller ||
                !readIds.contains(message.orderMessageId) ||
                message.read) {
              return message;
            }

            changed = true;
            return message.copyWith(
              read: true,
              readAt: event.occurredAt,
            );
          },
        ).toList(growable: false);

        if (!changed) {
          return;
        }

        setState(() {
          _conversation = _withMessages(
            conversation,
            nextMessages,
          );
        });

        return;
    }
  }

  bool _rememberEventId(String eventId) {
    if (_rememberedEventIds.contains(eventId)) {
      return false;
    }

    _rememberedEventIds.add(eventId);
    _rememberedEventIdOrder.add(eventId);

    while (_rememberedEventIdOrder.length >
        _maximumRememberedEventIds) {
      final removed = _rememberedEventIdOrder.removeAt(0);
      _rememberedEventIds.remove(removed);
    }

    return true;
  }

  void _markLatestCustomerMessageAsRead() {
    if (!mounted ||
        !_isAppActive ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    final conversation = _conversation;
    if (conversation == null) {
      return;
    }

    SellerOrderMessage? latestUnreadCustomerMessage;

    for (final message in conversation.messages.reversed) {
      if (message.sentByCustomer && !message.read) {
        latestUnreadCustomerMessage = message;
        break;
      }
    }

    if (latestUnreadCustomerMessage == null) {
      return;
    }

    final sent = _realtimeClient?.markChatMessagesAsRead(
          orderPublicId: widget.orderPublicId,
          lastReadMessageId:
              latestUnreadCustomerMessage.orderMessageId,
        ) ??
        false;

    if (!sent) {
      unawaited(
        _markMessagesAsReadByRest(),
      );
    }
  }

  Future<void> _markMessagesAsReadByRest() async {
    final storeId = _selectedStoreId;

    if (storeId == null || !_isAppActive) {
      return;
    }

    try {
      await widget.repository.findMessagePage(
        storeId,
        widget.orderPublicId,
        size: 1,
      );
    } catch (error) {
      debugPrint(
        '판매자 메시지 읽음 REST fallback 실패: $error',
      );
    }
  }

  void _updatePollingForConnection() {
    if (!_isAppActive) {
      _stopPolling();
      return;
    }

    if (_realtimeClient?.shouldUseRestFallback ?? true) {
      _startPolling();
      return;
    }

    _stopPolling();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.position.pixels >
            _olderMessageTriggerOffset) {
      return;
    }

    unawaited(_loadOlderMessages());
  }

  void _handleStoreSelectionChanged() {
    if (!mounted) {
      return;
    }

    final storeId = _selectedStoreId;

    if (_loadedStoreId == storeId) {
      return;
    }

    _requestSerial++;
    _resetConversationState();
    _subscribeToOrderChat();
    _loadConversation();
    _updatePollingForConnection();
  }

  void _resetConversationState() {
    _cancelAllConfirmationTimers();
    _conversation = null;
    _outgoingDrafts.clear();
    _sending = false;
    _refreshing = false;
    _loadingOlder = false;
    _loadedStoreId = null;
    _hasMoreOlder = false;
    _hasLoadedOlderPages = false;
    _nextBeforeMessageId = null;
  }

  Future<void> _loadConversation() async {
    final storeId = _selectedStoreId;
    final requestSerial = ++_requestSerial;

    setState(() {
      _loading = true;
      _refreshing = false;
      _loadingOlder = false;
      _error = null;
    });

    if (storeId == null) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }

      setState(() {
        _conversation = null;
        _error = StateError('selected store is missing');
        _loading = false;
      });
      return;
    }

    try {
      final metadataFuture = widget.repository.findConversationMetadata(
        storeId,
        widget.orderPublicId,
      );
      final pageFuture = widget.repository.findMessagePage(
        storeId,
        widget.orderPublicId,
        size: _pageSize,
      );

      final metadata = await metadataFuture;
      final page = await pageFuture;

      if (!mounted ||
          requestSerial != _requestSerial ||
          _selectedStoreId != storeId) {
        return;
      }

      setState(() {
        _loadedStoreId = storeId;
        _removeConfirmedDrafts(page.messages);
        _conversation = _withMessages(metadata, page.messages);
        _hasMoreOlder = page.hasMore;
        _nextBeforeMessageId = page.nextBeforeMessageId;
        _hasLoadedOlderPages = false;
        _error = null;
        _loading = false;
      });

      _scrollToLatestMessage(animate: false);
      _markLatestCustomerMessageAsRead();
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    final storeId = _selectedStoreId;
    final conversation = _conversation;

    if (!mounted ||
        storeId == null ||
        conversation == null ||
        _loading ||
        _refreshing ||
        _pollRequestInProgress ||
        _loadingOlder ||
        !_hasMoreOlder) {
      return;
    }

    final int? beforeMessageId = _nextBeforeMessageId ??
        (conversation.messages.isEmpty
            ? null
            : conversation.messages.first.orderMessageId);

    if (beforeMessageId == null) {
      setState(() {
        _hasMoreOlder = false;
      });
      return;
    }

    final requestSerial = ++_requestSerial;
    final double previousMaxScrollExtent =
        _scrollController.hasClients
            ? _scrollController.position.maxScrollExtent
            : 0;
    final double previousOffset = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0;

    setState(() {
      _loadingOlder = true;
    });

    try {
      final page = await widget.repository.findMessagePage(
        storeId,
        widget.orderPublicId,
        beforeMessageId: beforeMessageId,
        size: _pageSize,
      );

      if (!mounted ||
          requestSerial != _requestSerial ||
          _selectedStoreId != storeId) {
        return;
      }

      final currentConversation = _conversation;
      if (currentConversation == null) {
        return;
      }

      final mergedMessages = _mergeMessages(
        page.messages,
        currentConversation.messages,
      );

      setState(() {
        _conversation = _withMessages(
          currentConversation,
          mergedMessages,
        );
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
      if (!mounted ||
          requestSerial != _requestSerial ||
          _selectedStoreId != storeId) {
        return;
      }

      setState(() {
        _loadingOlder = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이전 메시지를 불러오지 못했어요.'),
        ),
      );
    }
  }

  Future<void> _refreshConversation() async {
    final storeId = _selectedStoreId;

    if (storeId == null ||
        _loading ||
        _refreshing ||
        _loadingOlder ||
        _pollRequestInProgress) {
      return;
    }

    final requestSerial = ++_requestSerial;
    final bool shouldStickToBottom = _isNearBottom();

    setState(() {
      _refreshing = true;
    });

    try {
      final metadataFuture = widget.repository.findConversationMetadata(
        storeId,
        widget.orderPublicId,
      );
      final pageFuture = widget.repository.findMessagePage(
        storeId,
        widget.orderPublicId,
        size: _pageSize,
      );

      final metadata = await metadataFuture;
      final page = await pageFuture;

      if (!mounted ||
          requestSerial != _requestSerial ||
          _selectedStoreId != storeId) {
        return;
      }

      final previousMessages = _conversation?.messages ?? const [];
      final bool hasNewMessage = _containsNewMessages(
        previousMessages,
        page.messages,
      );
      final nextMessages = _hasLoadedOlderPages
          ? _mergeMessages(previousMessages, page.messages)
          : page.messages;

      setState(() {
        _removeConfirmedDrafts(nextMessages);
        _loadedStoreId = storeId;
        _conversation = _withMessages(metadata, nextMessages);
        if (!_hasLoadedOlderPages) {
          _hasMoreOlder = page.hasMore;
          _nextBeforeMessageId = page.nextBeforeMessageId;
        }
        _error = null;
      });

      if (hasNewMessage && shouldStickToBottom) {
        _scrollToLatestMessage();
      }
    } catch (_) {
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최신 메시지를 불러오지 못했어요.'),
        ),
      );
    } finally {
      if (mounted &&
          requestSerial == _requestSerial &&
          _selectedStoreId == storeId) {
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

  void _restartPolling() {
    _stopPolling();
    _updatePollingForConnection();
  }

  Future<void> _pollConversation({
    bool force = false,
  }) async {
    if (!mounted ||
        (!_isAppActive) ||
        (!force &&
            !(_realtimeClient?.shouldUseRestFallback ?? true)) ||
        _loading ||
        _sending ||
        _refreshing ||
        _loadingOlder ||
        _pollRequestInProgress) {
      return;
    }

    final storeId = _selectedStoreId;
    if (storeId == null) {
      return;
    }

    _pollRequestInProgress = true;
    final requestSerial = ++_requestSerial;
    final bool shouldStickToBottom = _isNearBottom();

    try {
      final metadataFuture = widget.repository.findConversationMetadata(
        storeId,
        widget.orderPublicId,
      );
      final pageFuture = widget.repository.findMessagePage(
        storeId,
        widget.orderPublicId,
        size: _pageSize,
      );

      final metadata = await metadataFuture;
      final page = await pageFuture;

      if (!mounted ||
          requestSerial != _requestSerial ||
          _selectedStoreId != storeId) {
        return;
      }

      final previousConversation = _conversation;
      final previousMessages = previousConversation?.messages ?? const [];
      final bool hasNewMessage = _containsNewMessages(
        previousMessages,
        page.messages,
      );
      final nextMessages = _hasLoadedOlderPages
          ? _mergeMessages(previousMessages, page.messages)
          : page.messages;
      final nextConversation = _withMessages(metadata, nextMessages);

      if (!_hasConversationChanged(
        previousConversation,
        nextConversation,
      )) {
        return;
      }

      setState(() {
        _removeConfirmedDrafts(nextMessages);
        _loadedStoreId = storeId;
        _conversation = nextConversation;
        if (!_hasLoadedOlderPages) {
          _hasMoreOlder = page.hasMore;
          _nextBeforeMessageId = page.nextBeforeMessageId;
        }
        _error = null;
      });

      if (hasNewMessage && shouldStickToBottom) {
        _scrollToLatestMessage();
      }
    } catch (error, stackTrace) {
      debugPrint('고객 문의 상세 자동 갱신 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _pollRequestInProgress = false;
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    final storeId = _selectedStoreId;

    if (content.isEmpty || _sending || storeId == null) {
      return;
    }

    if (content.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
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
    await _deliverDraft(
      localId: draft.localId,
      storeId: storeId,
    );
  }

  Future<void> _retryMessage(int localId) async {
    final storeId = _selectedStoreId;

    if (_sending || storeId == null) {
      return;
    }

    final draftIndex = _outgoingDrafts.indexWhere(
      (draft) => draft.localId == localId,
    );

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

    await _deliverDraft(
      localId: localId,
      storeId: storeId,
    );
  }

  Future<void> _deliverDraft({
    required int localId,
    required int storeId,
    bool forceRest = false,
  }) async {
    final draftIndex = _outgoingDrafts.indexWhere(
      (draft) => draft.localId == localId,
    );

    if (draftIndex < 0) {
      if (mounted) {
        setState(() {
          _sending = _outgoingDrafts.any(
            (draft) =>
                draft.status == _OutgoingMessageStatus.sending,
          );
        });
      }
      return;
    }

    final draft = _outgoingDrafts[draftIndex];
    final orderPublicId = widget.orderPublicId;

    if (!forceRest && (_realtimeClient?.isConnected ?? false)) {
      final sent = _realtimeClient!.sendChatMessage(
        orderPublicId: orderPublicId,
        content: draft.content,
        clientMessageId: draft.clientMessageId,
      );

      if (sent) {
        if (_outgoingDrafts.any(
          (item) => item.localId == localId,
        )) {
          _scheduleRestFallback(
            localId: localId,
            storeId: storeId,
            clientMessageId: draft.clientMessageId,
          );
        }
        return;
      }
    }

    _cancelConfirmationTimer(draft.clientMessageId);

    try {
      final sentMessage = await widget.repository.sendMessage(
        storeId,
        orderPublicId,
        content: draft.content,
        clientMessageId: draft.clientMessageId,
      );

      if (!mounted ||
          _selectedStoreId != storeId ||
          widget.orderPublicId != orderPublicId) {
        return;
      }

      setState(() {
        _removeConfirmedDraftForMessage(sentMessage);

        final conversation = _conversation;
        if (conversation != null) {
          _conversation = _withMessages(
            conversation,
            _mergeMessages(
              conversation.messages,
              <SellerOrderMessage>[sentMessage],
            ),
          );
        }

        _sending = _outgoingDrafts.any(
          (item) =>
              item.status == _OutgoingMessageStatus.sending,
        );
      });

      _scrollToLatestMessage();
      _messageFocusNode.requestFocus();
    } catch (error) {
      if (!mounted ||
          _selectedStoreId != storeId ||
          widget.orderPublicId != orderPublicId) {
        return;
      }

      final failedIndex = _outgoingDrafts.indexWhere(
        (item) => item.localId == localId,
      );

      if (failedIndex < 0) {
        return;
      }

      setState(() {
        _outgoingDrafts[failedIndex] =
            _outgoingDrafts[failedIndex].copyWith(
          status: _OutgoingMessageStatus.failed,
        );
        _sending = false;
      });

      debugPrint('판매자 메시지 전송 실패: $error');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '메시지 전송에 실패했어요. 말풍선 아래 재전송을 눌러 주세요.',
          ),
        ),
      );
    }
  }

  void _scheduleRestFallback({
    required int localId,
    required int storeId,
    required String clientMessageId,
  }) {
    _cancelConfirmationTimer(clientMessageId);

    _confirmationTimers[clientMessageId] = Timer(
      _serverConfirmationTimeout,
      () {
        _confirmationTimers.remove(clientMessageId);

        if (!mounted ||
            !_outgoingDrafts.any(
              (draft) =>
                  draft.localId == localId &&
                  draft.clientMessageId == clientMessageId,
            )) {
          return;
        }

        unawaited(
          _deliverDraft(
            localId: localId,
            storeId: storeId,
            forceRest: true,
          ),
        );
      },
    );
  }

  void _cancelConfirmationTimer(String clientMessageId) {
    _confirmationTimers.remove(clientMessageId)?.cancel();
  }

  void _cancelAllConfirmationTimers() {
    for (final timer in _confirmationTimers.values) {
      timer.cancel();
    }
    _confirmationTimers.clear();
  }

  void _removeConfirmedDrafts(
    Iterable<SellerOrderMessage> messages,
  ) {
    for (final message in messages) {
      _removeConfirmedDraftForMessage(message);
    }

    _sending = _outgoingDrafts.any(
      (draft) =>
          draft.status == _OutgoingMessageStatus.sending,
    );
  }

  void _removeConfirmedDraftForMessage(
    SellerOrderMessage message,
  ) {
    if (!message.sentBySeller || _outgoingDrafts.isEmpty) {
      return;
    }

    int draftIndex = -1;
    final clientMessageId = message.clientMessageId?.trim();

    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      draftIndex = _outgoingDrafts.indexWhere(
        (draft) => draft.clientMessageId == clientMessageId,
      );
    }

    if (draftIndex < 0) {
      draftIndex = _outgoingDrafts.indexWhere(
        (draft) {
          final timeDifference = message.createdAt
              .difference(draft.createdAt)
              .abs();

          return draft.content == message.content &&
              timeDifference <= const Duration(minutes: 2);
        },
      );
    }

    if (draftIndex < 0) {
      return;
    }

    final removed = _outgoingDrafts.removeAt(draftIndex);
    _cancelConfirmationTimer(removed.clientMessageId);
  }

  SellerConversationDetail _withMessages(
    SellerConversationDetail conversation,
    List<SellerOrderMessage> messages,
  ) {
    return SellerConversationDetail(
      orderPublicId: conversation.orderPublicId,
      storeId: conversation.storeId,
      storeName: conversation.storeName,
      customerUserId: conversation.customerUserId,
      customerName: conversation.customerName,
      orderType: conversation.orderType,
      orderStatus: conversation.orderStatus,
      totalAmount: conversation.totalAmount,
      orderedAt: conversation.orderedAt,
      orderItems: conversation.orderItems,
      messages: messages,
    );
  }

  List<SellerOrderMessage> _mergeMessages(
    List<SellerOrderMessage> first,
    List<SellerOrderMessage> second,
  ) {
    final messagesById = <int, SellerOrderMessage>{};

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

    return List<SellerOrderMessage>.unmodifiable(messages);
  }

  bool _containsNewMessages(
    List<SellerOrderMessage> current,
    List<SellerOrderMessage> incoming,
  ) {
    final currentIds = current
        .map((message) => message.orderMessageId)
        .toSet();

    return incoming.any(
      (message) => !currentIds.contains(message.orderMessageId),
    );
  }

  bool _hasConversationChanged(
    SellerConversationDetail? previous,
    SellerConversationDetail next,
  ) {
    if (previous == null) {
      return true;
    }

    if (previous.storeName != next.storeName ||
        previous.customerName != next.customerName ||
        previous.orderType != next.orderType ||
        previous.orderStatus != next.orderStatus ||
        previous.totalAmount != next.totalAmount ||
        previous.orderItems.length != next.orderItems.length ||
        previous.messages.length != next.messages.length) {
      return true;
    }

    for (var index = 0; index < next.orderItems.length; index++) {
      final previousItem = previous.orderItems[index];
      final nextItem = next.orderItems[index];

      if (previousItem.orderItemId != nextItem.orderItemId ||
          previousItem.productName != nextItem.productName ||
          previousItem.quantity != nextItem.quantity ||
          previousItem.itemTotalPrice != nextItem.itemTotalPrice) {
        return true;
      }
    }

    for (var index = 0; index < next.messages.length; index++) {
      final previousMessage = previous.messages[index];
      final nextMessage = next.messages[index];

      if (previousMessage.orderMessageId !=
              nextMessage.orderMessageId ||
          previousMessage.senderUserId !=
              nextMessage.senderUserId ||
          previousMessage.senderName != nextMessage.senderName ||
          previousMessage.senderType != nextMessage.senderType ||
          previousMessage.clientMessageId !=
              nextMessage.clientMessageId ||
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
      final addedExtent =
          position.maxScrollExtent - previousMaxScrollExtent;
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
    required this.conversation,
  });

  final SellerConversationDetail conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final itemSummary = conversation.orderItems
        .map(
          (item) =>
      '${item.productName} ${item.quantity}개',
    )
        .join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        PopqSpacing.md,
        PopqSpacing.sm,
        PopqSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(
        PopqSpacing.md,
      ),
      decoration: BoxDecoration(
        color:
        colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatPopqOrderNumber(
                    conversation.orderPublicId,
                  ),
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    color: colorScheme.primary,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(
                status:
                conversation.orderStatus,
              ),
            ],
          ),
          const SizedBox(
            height: PopqSpacing.xs,
          ),
          Text(
            itemSummary.isEmpty
                ? '주문 상품 정보 없음'
                : itemSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.xs,
          ),
          Text(
            '${_orderTypeLabel(conversation.orderType)}'
                ' · ${conversation.totalQuantity}개'
                ' · ${_won(conversation.totalAmount)}',
            style: theme.textTheme.bodySmall,
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PopqSpacing.sm,
        vertical: PopqSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius:
        BorderRadius.circular(999),
      ),
      child: Text(
        _orderStatusLabel(status),
        style: theme.textTheme.bodySmall
            ?.copyWith(
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
      padding: const EdgeInsets.symmetric(
        vertical: PopqSpacing.md,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Divider(),
          ),
          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: PopqSpacing.sm,
            ),
            child: Text(
              '${date.year}.'
                  '${_twoDigits(date.month)}.'
                  '${_twoDigits(date.day)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ),
          const Expanded(
            child: Divider(),
          ),
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
    final failed =
        draft.status == _OutgoingMessageStatus.failed;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: PopqSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    right: PopqSpacing.xs,
                  ),
                  child: Text(
                    '${_twoDigits(draft.createdAt.hour)}:'
                        '${_twoDigits(draft.createdAt.minute)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontSize: 10),
                  ),
                ),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth:
                      MediaQuery.sizeOf(context).width * 0.72,
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
                          ? Border.all(
                        color: colorScheme.error,
                      )
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
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                    ),
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

  final SellerOrderMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final sentBySeller =
        message.sentBySeller;

    final localCreatedAt =
    message.createdAt.toLocal();

    final bubbleColor = sentBySeller
        ? colorScheme.primary
        : colorScheme
        .surfaceContainerHighest;

    final foregroundColor = sentBySeller
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Align(
      alignment: sentBySeller
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: PopqSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: sentBySeller
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!sentBySeller)
              Padding(
                padding:
                const EdgeInsets.only(
                  left: PopqSpacing.xs,
                  bottom: PopqSpacing.xs,
                ),
                child: Text(
                  message.senderName,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                if (sentBySeller)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      right: PopqSpacing.xs,
                    ),
                    child: _MessageTime(
                      dateTime:
                      localCreatedAt,
                      read: message.read,
                      showRead: true,
                    ),
                  ),
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth:
                      MediaQuery.sizeOf(
                        context,
                      ).width *
                          0.72,
                    ),
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal:
                      PopqSpacing.md,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius:
                      BorderRadius.only(
                        topLeft:
                        const Radius.circular(
                          20,
                        ),
                        topRight:
                        const Radius.circular(
                          20,
                        ),
                        bottomLeft:
                        Radius.circular(
                          sentBySeller
                              ? 20
                              : 6,
                        ),
                        bottomRight:
                        Radius.circular(
                          sentBySeller
                              ? 6
                              : 20,
                        ),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color:
                        foregroundColor,
                      ),
                    ),
                  ),
                ),
                if (!sentBySeller)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      left: PopqSpacing.xs,
                    ),
                    child: _MessageTime(
                      dateTime:
                      localCreatedAt,
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
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(
      fontSize: 10,
    );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.end,
      children: [
        if (showRead)
          Text(
            read ? '읽음' : '전송됨',
            style: textStyle,
          ),
        Text(
          '${_twoDigits(dateTime.hour)}:'
              '${_twoDigits(dateTime.minute)}',
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
    final colorScheme =
        Theme.of(context).colorScheme;

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
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration:
                  const InputDecoration(
                    hintText:
                    '고객에게 답변을 입력하세요.',
                    counterText: '',
                    contentPadding:
                    EdgeInsets.symmetric(
                      horizontal:
                      PopqSpacing.md,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              IconButton.filled(
                tooltip: '메시지 전송',
                onPressed:
                sending ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                  dimension: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.send_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _orderTypeLabel(String value) {
  return switch (value) {
    'TAKEOUT' => '포장',
    'DINE_IN' => '매장 식사',
    'DELIVERY' => '배달',
    _ => value,
  };
}

String _orderStatusLabel(String value) {
  return switch (value) {
    'CREATED' => '결제 대기',
    'PLACED' => '접수 대기',
    'ACCEPTED' => '접수 완료',
    'PREPARING' => '준비 중',
    'READY' => '준비 완료',
    'COMPLETED' => '주문 완료',
    'REJECTED' => '주문 거절',
    'CANCELED' => '주문 취소',
    'EXPIRED' => '결제 만료',
    _ => value,
  };
}

String _won(int amount) {
  final digits = amount.toString();

  final buffer = StringBuffer();

  for (
  var index = 0;
  index < digits.length;
  index++
  ) {
    if (index > 0 &&
        (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return '$buffer원';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}