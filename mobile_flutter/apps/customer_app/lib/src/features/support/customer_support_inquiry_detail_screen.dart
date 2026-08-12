import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
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
                _InquiryHeader(inquiry: detail.inquiry),
                const SizedBox(height: 20),
                ...detail.messages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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

class _InquiryHeader extends StatelessWidget {
  const _InquiryHeader({required this.inquiry});

  final CustomerSupportInquirySummary inquiry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
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
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            inquiry.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDateTime(inquiry.createdAt),
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

  final CustomerSupportInquiryMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final sentByCustomer = message.sentByCustomer;

    return Align(
      alignment: sentByCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Column(
          crossAxisAlignment: sentByCustomer
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              sentByCustomer ? '나' : 'POPQ 고객센터',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: sentByCustomer
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: sentByCustomer
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(message.createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    final canSend =
        !widget.closed &&
        !widget.sending &&
        widget.controller.text.trim().isNotEmpty;

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: widget.closed
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('종료된 문의입니다.')),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        enabled: !widget.sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 3000,
                        decoration: const InputDecoration(
                          hintText: '추가로 문의할 내용을 입력하세요',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: canSend ? widget.onSend : null,
                      tooltip: '보내기',
                      icon: widget.sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
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
