import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../orders/customer_order_repository.dart';
import 'customer_order_message.dart';
import 'customer_order_message_repository.dart';

class CustomerOrderChatScreen extends StatefulWidget {
  const CustomerOrderChatScreen({
    required this.orderPublicId,
    required this.orderRepository,
    required this.messageRepository,
    super.key,
  });

  final String orderPublicId;
  final CustomerOrderRepository orderRepository;
  final CustomerOrderMessageRepository messageRepository;

  @override
  State<CustomerOrderChatScreen> createState() {
    return _CustomerOrderChatScreenState();
  }
}

class _CustomerOrderChatScreenState
    extends State<CustomerOrderChatScreen>
    with WidgetsBindingObserver {
  static const Duration _pollingInterval = Duration(
    seconds: 3,
  );

  final TextEditingController _messageController =
  TextEditingController();

  final FocusNode _messageFocusNode = FocusNode();

  final ScrollController _scrollController =
  ScrollController();

  CustomerOrder? _order;

  List<CustomerOrderMessage> _messages = const [];

  Object? _error;

  Timer? _pollingTimer;

  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;
  bool _polling = false;

  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadConversation();
    _startPolling();
  }

  @override
  void didUpdateWidget(
      covariant CustomerOrderChatScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.orderPublicId != widget.orderPublicId ||
        oldWidget.orderRepository != widget.orderRepository ||
        oldWidget.messageRepository != widget.messageRepository) {
      _requestGeneration++;

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
    _requestGeneration++;

    _stopPolling();

    WidgetsBinding.instance.removeObserver(this);

    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _order?.storeName ?? '주문 문의',
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ||
                _sending ||
                _refreshing
                ? null
                : _refreshConversation,
            icon: _refreshing
                ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
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
        message: '문의 내용을 불러오고 있어요.',
      );
    }

    if (_error != null || _order == null) {
      return PopqErrorView(
        message: '문의 내용을 불러오지 못했어요.',
        onRetry: _loadConversation,
      );
    }

    return Column(
      children: [
        _OrderSummaryCard(
          order: _order!,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshConversation,
            child: _messages.isEmpty
                ? const CustomScrollView(
              physics:
              AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PopqEmptyView(
                    icon: Icons
                        .chat_bubble_outline_rounded,
                    title: '아직 문의 내역이 없어요.',
                    description:
                    '아래 입력창에서 매장에 '
                        '궁금한 점을 남겨보세요.',
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
              itemCount: _messages.length,
              itemBuilder: (
                  context,
                  index,
                  ) {
                final message =
                _messages[index];

                final previousMessage =
                index == 0
                    ? null
                    : _messages[
                index - 1
                ];

                final currentDate =
                message.createdAt
                    .toLocal();

                final showDate =
                    previousMessage == null ||
                        !_isSameDay(
                          previousMessage
                              .createdAt
                              .toLocal(),
                          currentDate,
                        );

                return Column(
                  children: [
                    if (showDate)
                      _DateDivider(
                        date: currentDate,
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

  Future<void> _loadConversation() async {
    final generation = _requestGeneration;

    setState(() {
      _loading = true;
      _refreshing = false;
      _error = null;
    });

    try {
      final orderFuture =
      widget.orderRepository.findOne(
        widget.orderPublicId,
      );

      /*
       * 메시지 목록 조회 시 백엔드에서
       * 읽지 않은 판매자 메시지를 읽음 처리합니다.
       */
      final messagesFuture =
      widget.messageRepository.findMessages(
        widget.orderPublicId,
      );

      final order = await orderFuture;
      final messages = await messagesFuture;

      if (!mounted ||
          generation != _requestGeneration) {
        return;
      }

      setState(() {
        _order = order;
        _messages = messages;
        _loading = false;
        _error = null;
      });

      _scrollToLatestMessage();
    } catch (error) {
      if (!mounted ||
          generation != _requestGeneration) {
        return;
      }

      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _refreshConversation() async {
    if (_refreshing) {
      return;
    }

    final generation = _requestGeneration;

    setState(() {
      _refreshing = true;
    });

    try {
      final orderFuture =
      widget.orderRepository.findOne(
        widget.orderPublicId,
      );

      final messagesFuture =
      widget.messageRepository.findMessages(
        widget.orderPublicId,
      );

      final order = await orderFuture;
      final messages = await messagesFuture;

      if (!mounted ||
          generation != _requestGeneration) {
        return;
      }

      final hasNewMessage =
          messages.length > _messages.length;

      setState(() {
        _order = order;
        _messages = messages;
        _error = null;
      });

      if (hasNewMessage) {
        _scrollToLatestMessage();
      }
    } catch (_) {
      if (!mounted ||
          generation != _requestGeneration) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '최신 문의 내용을 불러오지 못했어요.',
          ),
        ),
      );
    } finally {
      if (mounted &&
          generation == _requestGeneration) {
        setState(() {
          _refreshing = false;
        });
      }
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
        _refreshing ||
        _polling) {
      return;
    }

    final generation = _requestGeneration;

    _polling = true;

    try {
      /*
       * 이 API 호출은 새 판매자 답변을 가져오면서
       * 해당 판매자 메시지를 읽음 처리합니다.
       *
       * 판매자가 고객 메시지를 확인했다면
       * 고객 메시지의 read 값도 최신 상태로 내려옵니다.
       */
      final messages =
      await widget.messageRepository.findMessages(
        widget.orderPublicId,
      );

      if (!mounted ||
          generation != _requestGeneration) {
        return;
      }

      if (!_haveMessagesChanged(
        _messages,
        messages,
      )) {
        return;
      }

      final hasNewMessage =
          messages.length > _messages.length;

      setState(() {
        _messages = messages;
        _error = null;
      });

      if (hasNewMessage) {
        _scrollToLatestMessage();
      }
    } catch (error, stackTrace) {
      /*
       * 자동 갱신 실패 시 기존 채팅 화면은 유지하고
       * 다음 주기에 다시 조회합니다.
       */
      debugPrint(
        '고객 주문 문의 자동 갱신 실패: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _polling = false;
    }
  }

  Future<void> _sendMessage() async {
    final content =
    _messageController.text.trim();

    if (content.isEmpty || _sending) {
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
      final sentMessage =
      await widget.messageRepository
          .sendMessage(
        orderPublicId: widget.orderPublicId,
        content: content,
      );

      if (!mounted) {
        return;
      }

      _messageController.clear();

      setState(() {
        _messages = [
          ..._messages,
          sentMessage,
        ];
      });

      _scrollToLatestMessage();

      _messageFocusNode.requestFocus();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '메시지를 보내지 못했어요. '
                '잠시 후 다시 시도해 주세요.',
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

  bool _haveMessagesChanged(
      List<CustomerOrderMessage> previous,
      List<CustomerOrderMessage> next,
      ) {
    if (previous.length != next.length) {
      return true;
    }

    for (
    var index = 0;
    index < next.length;
    index++
    ) {
      final previousMessage =
      previous[index];

      final nextMessage =
      next[index];

      if (previousMessage.orderMessageId !=
          nextMessage.orderMessageId ||
          previousMessage.senderUserId !=
              nextMessage.senderUserId ||
          previousMessage.senderName !=
              nextMessage.senderName ||
          previousMessage.senderType !=
              nextMessage.senderType ||
          previousMessage.content !=
              nextMessage.content ||
          previousMessage.read !=
              nextMessage.read ||
          previousMessage.readAt !=
              nextMessage.readAt ||
          previousMessage.createdAt !=
              nextMessage.createdAt) {
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
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.storeName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              _StatusChip(
                status: order.status,
              ),
            ],
          ),
          const SizedBox(
            height: PopqSpacing.sm,
          ),
          Text(
            '주문번호',
            style:
            theme.textTheme.bodySmall?.copyWith(
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),
          const SizedBox(
            height: PopqSpacing.xs,
          ),
          SelectableText(
            order.orderPublicId,
            style:
            theme.textTheme.bodyMedium?.copyWith(
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
        borderRadius:
        BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
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

  final CustomerOrderMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sentByCustomer =
        message.sentByCustomer;

    final localCreatedAt =
    message.createdAt.toLocal();

    final bubbleColor = sentByCustomer
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;

    final foregroundColor = sentByCustomer
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Align(
      alignment: sentByCustomer
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: PopqSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: sentByCustomer
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!sentByCustomer)
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
                if (sentByCustomer)
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
                          sentByCustomer
                              ? 20
                              : 6,
                        ),
                        bottomRight:
                        Radius.circular(
                          sentByCustomer
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
                if (!sentByCustomer)
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
                  textInputAction:
                  TextInputAction.newline,
                  decoration:
                  const InputDecoration(
                    hintText:
                    '매장에 문의할 내용을 입력하세요.',
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