import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../../realtime/seller_realtime_scope.dart';
import 'seller_support_repository.dart';
import 'seller_support_ticket.dart';
import 'seller_support_types.dart';

class SellerSupportTicketDetailScreen extends StatefulWidget {
  const SellerSupportTicketDetailScreen({
    required this.repository,
    required this.supportTicketId,
    super.key,
  });

  final SellerSupportRepository repository;
  final int supportTicketId;

  @override
  State<SellerSupportTicketDetailScreen> createState() {
    return _SellerSupportTicketDetailScreenState();
  }
}

class _SellerSupportTicketDetailScreenState
    extends State<SellerSupportTicketDetailScreen> {
  static const int _maxMessageLength = 4000;

  final TextEditingController _messageController = TextEditingController();

  SellerSupportTicketDetail? _detail;
  bool _loading = true;
  bool _sending = false;
  String? _errorMessage;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _supportSubscription;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageChanged);
    _loadDetail();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextClient = SellerRealtimeScope.maybeOf(context);

    if (identical(_realtimeClient, nextClient)) {
      return;
    }

    _supportSubscription?.cancel();
    _supportSubscription = null;
    _realtimeClient = nextClient;

    if (nextClient == null) {
      return;
    }

    _supportSubscription = nextClient.subscribeToSupportTickets(
      onEvent: (event) {
        if (event.ticketId != widget.supportTicketId) {
          return;
        }

        unawaited(_loadDetail());
      },
    );
  }

  @override
  void dispose() {
    _supportSubscription?.cancel();
    _supportSubscription = null;
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _handleMessageChanged() {
    setState(() {});
  }

  Future<void> _loadDetail() async {
    final showInitialLoading = _detail == null;

    setState(() {
      if (showInitialLoading) {
        _loading = true;
      }

      _errorMessage = null;
    });

    try {
      final detail = await widget.repository.getMyTicket(
        widget.supportTicketId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _loading = false;
      });

      if (detail.ticket.hasUnreadMessages) {
        await _markAsRead();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = '문의 내용을 불러오지 못했어요.';
      });
    }
  }

  Future<void> _markAsRead() async {
    try {
      final updated = await widget.repository.markTicketAsRead(
        widget.supportTicketId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = updated;
      });
    } catch (_) {
      // 읽음 처리 실패는 문의 내용 확인을 막지 않습니다.
    }
  }

  Future<void> _sendMessage() async {
    if (_sending) {
      return;
    }

    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    if (content.length > _maxMessageLength) {
      setState(() {
        _errorMessage = '메시지는 4000자 이하로 입력해 주세요.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.repository.sendMessage(
        supportTicketId: widget.supportTicketId,
        content: content,
      );

      if (!mounted) {
        return;
      }

      _messageController.clear();

      setState(() {
        _detail = updated;
        _sending = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
        _errorMessage = error is StateError || error is ArgumentError
            ? error.toString().replaceFirst(
                RegExp(r'^(Bad state|Invalid argument):\s*'),
                '',
              )
            : '메시지를 보내지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의 상세'), centerTitle: true),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final detail = _detail;

    if (detail == null) {
      return _DetailMessage(
        message: _errorMessage ?? '문의 내용을 찾을 수 없어요.',
        onRetry: _loadDetail,
      );
    }

    final closed = detail.ticket.status == SellerSupportStatus.closed;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDetail,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _TicketHeader(
                  ticket: detail.ticket,
                  firstMessage:
                  detail.messages.isEmpty ? null : detail.messages.first,
                ),
                const SizedBox(height: 24),
            _TicketReplySection(
              messages: detail.messages.skip(1).toList(growable: false),
              additionalInquiryForm: _MessageComposer(
                controller: _messageController,
                closed: closed,
                sending: _sending,
                onSend: _sendMessage,
              ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({
    required this.ticket,
    required this.firstMessage,
  });

  final SellerSupportTicketSummary ticket;
  final SellerSupportMessage? firstMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내가 보낸 문의',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    ticket.category.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ticket.status.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ticket.subject,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDateTime(ticket.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 18),
              Text(
                '문의 내용',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                firstMessage?.content ?? '등록된 문의 내용이 없습니다.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketReplySection extends StatelessWidget {
  const _TicketReplySection({
    required this.messages,
    required this.additionalInquiryForm,
  });

  final List<SellerSupportMessage> messages;
  final Widget additionalInquiryForm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '답변 및 추가 문의',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '관리자 답변을 기다리고 있어요.',
                          textAlign: TextAlign.center,
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: List<Widget>.generate(
                    messages.length,
                        (index) {
                      final message = messages[index];

                      final firstAdminReply = !message.sentBySeller &&
                          messages
                              .take(index)
                              .where((item) => !item.sentBySeller)
                              .isEmpty;

                      final hasSellerFollowUpBefore = messages
                          .take(index)
                          .any((item) => item.sentBySeller);

                      return _TicketReplyItem(
                        message: message,
                        firstAdminReply: firstAdminReply,
                        hasSellerFollowUpBefore: hasSellerFollowUpBefore,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              additionalInquiryForm,
            ],
          ),
        ),
      ],
    );
  }
}


class _TicketReplyItem extends StatelessWidget {
  const _TicketReplyItem({
    required this.message,
    required this.firstAdminReply,
    required this.hasSellerFollowUpBefore,
  });

  final SellerSupportMessage message;
  final bool firstAdminReply;
  final bool hasSellerFollowUpBefore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sentBySeller = message.sentBySeller;

    final title = sentBySeller
        ? '내가 한 추가 문의'
        : firstAdminReply
        ? '관리자 답변'
        : '관리자 추가 답변';

    final icon = sentBySeller
        ? Icons.person_outline_rounded
        : Icons.support_agent_rounded;

    final accentColor =
    sentBySeller ? colorScheme.tertiary : colorScheme.primary;

    final leftPadding = sentBySeller
        ? 20.0
        : hasSellerFollowUpBefore
        ? 40.0
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leftPadding > 0) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: 22,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                    accentColor.withValues(alpha: 0.12),
                    foregroundColor: accentColor,
                    child: Icon(
                      icon,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateTime(message.createdAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          message.content,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.closed,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool closed;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final canSend =
        !closed &&
            !sending &&
            controller.text.trim().isNotEmpty;

    if (closed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '추가 문의',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '종료된 문의에는 추가 문의를 등록할 수 없어요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '추가 문의',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          enabled: !sending,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '추가로 문의할 내용을 입력해 주세요.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: canSend ? onSend : null,
            child: sending
                ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
                : const Text('등록'),
          ),
        ),
      ],
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  String twoDigits(int number) {
    return number.toString().padLeft(2, '0');
  }

  return '${local.year}.${twoDigits(local.month)}.'
      '${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
