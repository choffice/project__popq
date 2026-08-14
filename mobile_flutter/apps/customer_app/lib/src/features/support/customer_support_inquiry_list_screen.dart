import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../../realtime/customer_realtime_scope.dart';
import 'customer_support_inquiry.dart';
import 'customer_support_repository.dart';
import 'customer_support_types.dart';

class CustomerSupportInquiryListScreen extends StatefulWidget {
  const CustomerSupportInquiryListScreen({
    required this.repository,
    required this.onInquiryTap,
    super.key,
  });

  final CustomerSupportRepository repository;
  final ValueChanged<int> onInquiryTap;

  @override
  State<CustomerSupportInquiryListScreen> createState() {
    return _CustomerSupportInquiryListScreenState();
  }
}

class _CustomerSupportInquiryListScreenState
    extends State<CustomerSupportInquiryListScreen> {
  List<CustomerSupportInquirySummary> _inquiries = const [];

  bool _loading = true;
  String? _errorMessage;

  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _supportSubscription;

  @override
  void initState() {
    super.initState();
    _loadInquiries();
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
        if (event.requesterType != 'CUSTOMER') {
          return;
        }

        unawaited(_loadInquiries());
      },
    );
  }

  @override
  void dispose() {
    _supportSubscription?.cancel();
    _supportSubscription = null;
    super.dispose();
  }

  Future<void> _loadInquiries() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final inquiries = await widget.repository.getMyInquiries();

      if (!mounted) {
        return;
      }

      setState(() {
        _inquiries = inquiries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = '문의 내역을 불러오지 못했어요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의 내역'), centerTitle: true),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _InquiryListMessage(
        icon: Icons.error_outline_rounded,
        message: _errorMessage!,
        buttonLabel: '다시 시도',
        onPressed: _loadInquiries,
      );
    }

    if (_inquiries.isEmpty) {
      return const _InquiryListMessage(
        icon: Icons.forum_outlined,
        message: '아직 등록한 문의가 없어요.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInquiries,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: _inquiries.length,
        separatorBuilder: (_, _) {
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          final inquiry = _inquiries[index];

          return _InquiryListCard(
            inquiry: inquiry,
            onTap: () {
              widget.onInquiryTap(inquiry.supportInquiryId);
            },
          );
        },
      ),
    );
  }
}

class _InquiryListCard extends StatelessWidget {
  const _InquiryListCard({required this.inquiry, required this.onTap});

  final CustomerSupportInquirySummary inquiry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: inquiry.status),
                  const Spacer(),
                  Text(
                    _formatDate(inquiry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                inquiry.category.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inquiry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (inquiry.unreadMessageCount > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.mark_chat_unread_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '새 답변 '
                      '${inquiry.unreadMessageCount}개',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CustomerSupportStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (backgroundColor, foregroundColor) = switch (status) {
      CustomerSupportStatus.received => (
      colorScheme.secondaryContainer,
      colorScheme.onSecondaryContainer,
      ),
      CustomerSupportStatus.waitingAdmin => (
      colorScheme.tertiaryContainer,
      colorScheme.onTertiaryContainer,
      ),
      CustomerSupportStatus.waitingRequester => (
      colorScheme.primaryContainer,
      colorScheme.onPrimaryContainer,
      ),
      CustomerSupportStatus.closed => (
      colorScheme.surfaceContainerHighest,
      colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InquiryListMessage extends StatelessWidget {
  const _InquiryListMessage({
    required this.icon,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 14),
            Text(message),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: onPressed,
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');

  return '${local.year}.$month.$day';
}
