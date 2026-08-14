import 'dart:async';

import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../../realtime/seller_realtime_scope.dart';
import 'seller_support_repository.dart';
import 'seller_support_ticket.dart';
import 'seller_support_types.dart';

class SellerSupportTicketListScreen extends StatefulWidget {
  const SellerSupportTicketListScreen({
    required this.repository,
    required this.onTicketTap,
    super.key,
  });

  final SellerSupportRepository repository;
  final ValueChanged<int> onTicketTap;

  @override
  State<SellerSupportTicketListScreen> createState() {
    return _SellerSupportTicketListScreenState();
  }
}

class _SellerSupportTicketListScreenState
    extends State<SellerSupportTicketListScreen> {
  List<SellerSupportTicketSummary> _tickets = const [];
  bool _loading = true;
  String? _errorMessage;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _supportSubscription;

  @override
  void initState() {
    super.initState();
    _loadTickets();
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
      onEvent: (_) {
        unawaited(_loadTickets());
      },
    );
  }

  @override
  void dispose() {
    _supportSubscription?.cancel();
    _supportSubscription = null;
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final tickets = await widget.repository.getMyTickets();

      if (!mounted) {
        return;
      }

      setState(() {
        _tickets = tickets;
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
      appBar: AppBar(title: const Text('내 문의 내역'), centerTitle: true),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _TicketListMessage(
        icon: Icons.error_outline_rounded,
        message: _errorMessage!,
        actionLabel: '다시 시도',
        onAction: _loadTickets,
      );
    }

    if (_tickets.isEmpty) {
      return const _TicketListMessage(
        icon: Icons.forum_outlined,
        message: '아직 등록한 문의가 없어요.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        itemCount: _tickets.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          final ticket = _tickets[index];

          return _TicketCard(
            ticket: ticket,
            onTap: () {
              widget.onTicketTap(ticket.supportTicketId);
            },
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SellerSupportTicketSummary ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
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
                  _CategoryBadge(category: ticket.category),
                  const Spacer(),
                  _StatusBadge(status: ticket.status),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (ticket.hasUnreadMessages) ...[
                    const SizedBox(width: 10),
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        ticket.unreadMessageCount > 99
                            ? '99+'
                            : '${ticket.unreadMessageCount}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onError,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '최근 메시지 ${_formatDateTime(ticket.lastMessageAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final SellerSupportCategory category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SellerSupportStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(Theme.of(context).colorScheme, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TicketListMessage extends StatelessWidget {
  const _TicketListMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupportStatusColors {
  const _SupportStatusColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

_SupportStatusColors _statusColors(
  ColorScheme colorScheme,
  SellerSupportStatus status,
) {
  return switch (status) {
    SellerSupportStatus.received => _SupportStatusColors(
      background: colorScheme.secondaryContainer,
      foreground: colorScheme.onSecondaryContainer,
    ),
    SellerSupportStatus.waitingAdmin => _SupportStatusColors(
      background: colorScheme.tertiaryContainer,
      foreground: colorScheme.onTertiaryContainer,
    ),
    SellerSupportStatus.waitingRequester => _SupportStatusColors(
      background: colorScheme.primaryContainer,
      foreground: colorScheme.onPrimaryContainer,
    ),
    SellerSupportStatus.closed => _SupportStatusColors(
      background: colorScheme.surfaceContainerHighest,
      foreground: colorScheme.onSurfaceVariant,
    ),
  };
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
