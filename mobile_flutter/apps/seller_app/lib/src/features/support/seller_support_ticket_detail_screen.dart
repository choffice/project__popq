import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageChanged);
    _loadDetail();
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _handleMessageChanged() {
    setState(() {});
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
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
                _TicketHeader(ticket: detail.ticket),
                const SizedBox(height: 24),
                ...detail.messages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _MessageBubble(message: message),
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
        _MessageComposer(
          controller: _messageController,
          closed: closed,
          sending: _sending,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.ticket});

  final SellerSupportTicketSummary ticket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ticket.subject,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '문의일 ${_formatDateTime(ticket.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SellerSupportMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sentBySeller = message.sentBySeller;

    return Align(
      alignment: sentBySeller ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Column(
          crossAxisAlignment: sentBySeller
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                sentBySeller ? '판매자' : message.senderName,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: sentBySeller
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(sentBySeller ? 18 : 4),
                  bottomRight: Radius.circular(sentBySeller ? 4 : 18),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: sentBySeller
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _formatDateTime(message.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
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
    final canSend = !closed && !sending && controller.text.trim().isNotEmpty;

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: closed
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('종료된 문의입니다.', textAlign: TextAlign.center),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: !sending,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4000,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: '추가 문의 내용을 입력해 주세요',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: '메시지 전송',
                      onPressed: canSend ? onSend : null,
                      icon: sending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
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
