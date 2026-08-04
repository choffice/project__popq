import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

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

  final TextEditingController _messageController =
  TextEditingController();

  final FocusNode _messageFocusNode = FocusNode();

  final ScrollController _scrollController =
  ScrollController();

  SellerConversationDetail? _conversation;

  Object? _error;

  Timer? _pollingTimer;

  int? _loadedStoreId;

  int _requestSerial = 0;

  bool _loading = true;

  bool _sending = false;

  bool _pollRequestInProgress = false;

  int? get _selectedStoreId {
    return widget.selectionController.selectedStoreId;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    widget.selectionController.addListener(
      _handleStoreSelectionChanged,
    );

    _loadConversation();

    _startPolling();
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

      _loadedStoreId = null;

      _loadConversation();

      _restartPolling();
    }
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _startPolling();

      unawaited(
        _pollConversation(),
      );

      return;
    }

    _stopPolling();
  }

  @override
  void dispose() {
    _requestSerial++;

    _stopPolling();

    WidgetsBinding.instance.removeObserver(this);

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
        title: Text(
          conversation?.customerName ?? '고객 문의',
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading || _sending
                ? null
                : _refreshConversation,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
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

    return Column(
      children: [
        _OrderSummaryCard(
          conversation: conversation,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshConversation,
            child: conversation.messages.isEmpty
                ? const CustomScrollView(
              physics:
              AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PopqEmptyView(
                    icon: Icons
                        .chat_bubble_outline_rounded,
                    title: '아직 대화가 없어요.',
                    description:
                    '아래 입력창에서 고객에게 '
                        '첫 답변을 보내 보세요.',
                  ),
                ),
              ],
            )
                : ListView.builder(
              controller: _scrollController,
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                PopqSpacing.md,
                PopqSpacing.md,
                PopqSpacing.md,
                PopqSpacing.lg,
              ),
              itemCount:
              conversation.messages.length,
              itemBuilder: (
                  context,
                  index,
                  ) {
                final message =
                conversation.messages[index];

                final previousMessage =
                index == 0
                    ? null
                    : conversation
                    .messages[index - 1];

                final showDate =
                    previousMessage == null ||
                        !_isSameDay(
                          previousMessage.createdAt
                              .toLocal(),
                          message.createdAt
                              .toLocal(),
                        );

                return Column(
                  children: [
                    if (showDate)
                      _DateDivider(
                        date: message.createdAt
                            .toLocal(),
                      ),
                    _MessageBubble(
                      message: message,
                    ),
                  ],
                );
              },
            ),
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

  void _handleStoreSelectionChanged() {
    if (!mounted) {
      return;
    }

    final storeId = _selectedStoreId;

    if (_loadedStoreId == storeId) {
      return;
    }

    _requestSerial++;

    _loadedStoreId = null;

    _loadConversation();

    _restartPolling();
  }

  Future<void> _loadConversation() async {
    final storeId = _selectedStoreId;

    final requestSerial = ++_requestSerial;

    setState(() {
      _loading = true;
      _error = null;
    });

    if (storeId == null) {
      if (!mounted ||
          requestSerial != _requestSerial) {
        return;
      }

      setState(() {
        _conversation = null;

        _error = StateError(
          'selected store is missing',
        );

        _loading = false;
      });

      return;
    }

    try {
      final conversation =
      await widget.repository.findConversation(
        storeId,
        widget.orderPublicId,
      );

      if (!mounted ||
          requestSerial != _requestSerial ||
          _selectedStoreId != storeId) {
        return;
      }

      setState(() {
        _loadedStoreId = storeId;

        _conversation = conversation;

        _error = null;

        _loading = false;
      });

      _scrollToLatestMessage();
    } catch (error) {
      if (!mounted ||
          requestSerial != _requestSerial) {
        return;
      }

      setState(() {
        _error = error;

        _loading = false;
      });
    }
  }

  Future<void> _refreshConversation() async {
    final storeId = _selectedStoreId;

    if (storeId == null) {
      return;
    }

    final requestSerial = ++_requestSerial;

    try {
      final conversation =
      await widget.repository.findConversation(
        storeId,
        widget.orderPublicId,
      );

      if (!mounted ||
          requestSerial != _requestSerial ||
          _selectedStoreId != storeId) {
        return;
      }

      setState(() {
        _loadedStoreId = storeId;

        _conversation = conversation;

        _error = null;
      });

      _scrollToLatestMessage();
    } catch (error) {
      if (!mounted ||
          requestSerial != _requestSerial) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '최신 메시지를 불러오지 못했어요.',
          ),
        ),
      );
    }
  }

  void _startPolling() {
    if (_pollingTimer?.isActive ?? false) {
      return;
    }

    _pollingTimer = Timer.periodic(
      _pollingInterval,
          (_) {
        unawaited(
          _pollConversation(),
        );
      },
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = null;
  }

  void _restartPolling() {
    _stopPolling();

    _startPolling();
  }

  Future<void> _pollConversation() async {
    if (!mounted ||
        _loading ||
        _sending ||
        _pollRequestInProgress) {
      return;
    }

    final storeId = _selectedStoreId;

    if (storeId == null) {
      return;
    }

    _pollRequestInProgress = true;

    final requestSerial = ++_requestSerial;

    try {
      final conversation =
      await widget.repository.findConversation(
        storeId,
        widget.orderPublicId,
      );

      if (!mounted ||
          requestSerial != _requestSerial ||
          _selectedStoreId != storeId) {
        return;
      }

      final previousConversation =
          _conversation;

      final hasChanged =
      _hasConversationChanged(
        previousConversation,
        conversation,
      );

      if (!hasChanged) {
        return;
      }

      final hasNewMessage =
          previousConversation == null ||
              conversation.messages.length >
                  previousConversation
                      .messages.length;

      setState(() {
        _loadedStoreId = storeId;

        _conversation = conversation;

        _error = null;
      });

      if (hasNewMessage) {
        _scrollToLatestMessage();
      }
    } catch (error, stackTrace) {
      debugPrint(
        '고객 문의 상세 자동 갱신 실패: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _pollRequestInProgress = false;
    }
  }

  Future<void> _sendMessage() async {
    final content =
    _messageController.text.trim();

    final storeId = _selectedStoreId;

    if (content.isEmpty ||
        _sending ||
        storeId == null) {
      return;
    }

    if (content.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '메시지는 2,000자 이하로 입력해 주세요.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await widget.repository.sendMessage(
        storeId,
        widget.orderPublicId,
        content: content,
      );

      _messageController.clear();

      await _refreshConversation();

      if (!mounted) {
        return;
      }

      _messageFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '메시지를 보내지 못했어요. '
                '다시 시도해 주세요.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  bool _hasConversationChanged(
      SellerConversationDetail? previous,
      SellerConversationDetail next,
      ) {
    if (previous == null) {
      return true;
    }

    if (previous.orderStatus != next.orderStatus ||
        previous.totalAmount != next.totalAmount ||
        previous.messages.length !=
            next.messages.length) {
      return true;
    }

    for (
    var index = 0;
    index < next.messages.length;
    index++
    ) {
      final previousMessage =
      previous.messages[index];

      final nextMessage =
      next.messages[index];

      if (previousMessage.orderMessageId !=
          nextMessage.orderMessageId ||
          previousMessage.content !=
              nextMessage.content ||
          previousMessage.senderType !=
              nextMessage.senderType ||
          previousMessage.read !=
              nextMessage.read ||
          previousMessage.readAt !=
              nextMessage.readAt) {
        return true;
      }
    }

    return false;
  }

  void _scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (!mounted ||
            !_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController
              .position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 240,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  static bool _isSameDay(
      DateTime left,
      DateTime right,
      ) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
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
                  '#${conversation.orderPublicId}',
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