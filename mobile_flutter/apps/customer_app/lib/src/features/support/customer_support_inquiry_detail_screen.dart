import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../../realtime/customer_realtime_scope.dart';
import 'customer_support_inquiry.dart';
import 'customer_support_repository.dart';
import 'customer_support_types.dart';

class CustomerSupportInquiryDetailScreen extends StatefulWidget {
  const CustomerSupportInquiryDetailScreen({
    required this.repository,
    required this.supportInquiryId,
    super.key,
  });

  final CustomerSupportRepository repository;
  final int supportInquiryId;

  @override
  State<CustomerSupportInquiryDetailScreen> createState() {
    return _CustomerSupportInquiryDetailScreenState();
  }
}

class _CustomerSupportInquiryDetailScreenState
    extends State<CustomerSupportInquiryDetailScreen> {
  final TextEditingController _messageController = TextEditingController();

  CustomerSupportInquiryDetail? _detail;
  bool _loading = true;
  bool _sending = false;
  String? _errorMessage;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _supportSubscription;

  @override
  void dispose() {
    _supportSubscription?.cancel();
    _supportSubscription = null;
    _messageController.dispose();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextClient = CustomerRealtimeScope.maybeOf(context);

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
        if (event.ticketId != widget.supportInquiryId) {
          return;
        }

        if (event.requesterType != 'CUSTOMER') {
          return;
        }

        unawaited(_loadDetail());
      },
    );
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
      final detail = await widget.repository.getMyInquiry(
        widget.supportInquiryId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _loading = false;
      });
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

  Future<void> _sendMessage() async {
    if (_sending) {
      return;
    }

    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
      _errorMessage = null;
    });

    try {
      final detail = await widget.repository.sendMessage(
        supportInquiryId: widget.supportInquiryId,
        content: content,
      );

      if (!mounted) {
        return;
      }

      _messageController.clear();

      setState(() {
        _detail = detail;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
        _errorMessage = '메시지를 보내지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의 상세'), centerTitle: true),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final detail = _detail;

    if (_errorMessage != null && detail == null) {
      return _DetailMessage(message: _errorMessage!, onRetry: _loadDetail);
    }

    if (detail == null) {
      return const _DetailMessage(message: '문의 내용을 찾을 수 없어요.');
    }

    final closed = detail.inquiry.status == CustomerSupportStatus.closed;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDetail,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _InquiryHeader(
                  inquiry: detail.inquiry,
                  firstMessage:
                  detail.messages.isEmpty ? null : detail.messages.first,
                ),
                const SizedBox(height: 24),
                _InquiryReplySection(
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

class _InquiryHeader extends StatelessWidget {
  const _InquiryHeader({
    required this.inquiry,
    required this.firstMessage,
  });

  final CustomerSupportInquirySummary inquiry;
  final CustomerSupportInquiryMessage? firstMessage;

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
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    inquiry.category.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    inquiry.status.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                inquiry.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDateTime(inquiry.createdAt),
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
class _InquiryReplySection extends StatelessWidget {
  const _InquiryReplySection({
    required this.messages,
    required this.additionalInquiryForm,
  });

  final List<CustomerSupportInquiryMessage> messages;
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

                      final firstAdminReply = !message.sentByCustomer &&
                          messages
                              .take(index)
                              .where((item) => !item.sentByCustomer)
                              .isEmpty;

                      final hasCustomerFollowUpBefore = messages
                          .take(index)
                          .any((item) => item.sentByCustomer);

                      return _InquiryReplyItem(
                        message: message,
                        firstAdminReply: firstAdminReply,
                        hasCustomerFollowUpBefore: hasCustomerFollowUpBefore,
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

class _InquiryReplyItem extends StatelessWidget {
  const _InquiryReplyItem({
    required this.message,
    required this.firstAdminReply,
    required this.hasCustomerFollowUpBefore,
  });

  final CustomerSupportInquiryMessage message;
  final bool firstAdminReply;
  final bool hasCustomerFollowUpBefore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sentByCustomer = message.sentByCustomer;

    final title = sentByCustomer
        ? '내가 한 추가 문의'
        : firstAdminReply
        ? '관리자 답변'
        : '관리자 추가 답변';

    final icon = sentByCustomer
        ? Icons.person_outline_rounded
        : Icons.support_agent_rounded;

    final accentColor =
    sentByCustomer ? colorScheme.tertiary : colorScheme.primary;

    final leftPadding = sentByCustomer
        ? 20.0
        : hasCustomerFollowUpBefore
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
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
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
                                  color:
                                  colorScheme.onSurfaceVariant,
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
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatefulWidget {
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
  State<_MessageComposer> createState() {
    return _MessageComposerState();
  }
}

class _MessageComposerState extends State<_MessageComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant _MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final canSend =
        !widget.closed &&
            !widget.sending &&
            widget.controller.text.trim().isNotEmpty;

    if (widget.closed) {
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
          controller: widget.controller,
          enabled: !widget.sending,
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
            onPressed: canSend ? widget.onSend : null,
            child: widget.sending
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
  const _DetailMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 14),
            Text(message),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.year}.$month.$day $hour:$minute';
}
