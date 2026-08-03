import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_customer_repository.dart';

class SellerCustomerScreen extends StatefulWidget {
  const SellerCustomerScreen({
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final SellerCustomerRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerCustomerScreen> createState() {
    return _SellerCustomerScreenState();
  }
}

class _SellerCustomerScreenState extends State<SellerCustomerScreen> {
  int? _loadedStoreId;
  Future<List<SellerConversationSummary>>? _conversations;

  @override
  void initState() {
    super.initState();

    widget.selectionController.addListener(
      _handleStoreSelectionChanged,
    );

    _loadForCurrentStore();
  }

  @override
  void didUpdateWidget(
      covariant SellerCustomerScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectionController !=
        widget.selectionController) {
      oldWidget.selectionController.removeListener(
        _handleStoreSelectionChanged,
      );

      widget.selectionController.addListener(
        _handleStoreSelectionChanged,
      );

      _loadedStoreId = null;
      _loadForCurrentStore();
      return;
    }

    if (oldWidget.repository != widget.repository) {
      _loadedStoreId = null;
      _loadForCurrentStore();
    }
  }

  @override
  void dispose() {
    widget.selectionController.removeListener(
      _handleStoreSelectionChanged,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeId =
        widget.selectionController.selectedStoreId;

    if (storeId == null) {
      return const _NoSelectedStoreView();
    }

    final conversations = _conversations;

    if (conversations == null) {
      return const PopqLoadingView(
        message: '고객 문의를 불러오고 있어요.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            PopqSpacing.lg,
            PopqSpacing.lg,
            PopqSpacing.lg,
            PopqSpacing.sm,
          ),
          child: Text(
            '고객 문의 목록',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<SellerConversationSummary>>(
            future: conversations,
            builder: (context, snapshot) {
              if (snapshot.connectionState !=
                  ConnectionState.done &&
                  !snapshot.hasData) {
                return const PopqLoadingView(
                  message: '고객 문의를 불러오고 있어요.',
                );
              }

              if (snapshot.hasError) {
                return PopqErrorView(
                  message: '고객 문의 목록을 불러오지 못했어요.',
                  onRetry: _reload,
                );
              }

              final items =
                  snapshot.data ??
                      const <SellerConversationSummary>[];

              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: const CustomScrollView(
                    physics:
                    AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: PopqEmptyView(
                          icon: Icons.forum_outlined,
                          title: '도착한 고객 문의가 없어요.',
                          description:
                          '고객이 주문 문의를 보내면 '
                              '이곳에서 확인하고 답변할 수 있어요.',
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    PopqSpacing.lg,
                    PopqSpacing.sm,
                    PopqSpacing.lg,
                    PopqSpacing.xl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) {
                    return const SizedBox(
                      height: PopqSpacing.sm,
                    );
                  },
                  itemBuilder: (context, index) {
                    final conversation = items[index];

                    return _ConversationCard(
                      conversation: conversation,
                      onTap: () async {
                        await _openConversation(
                          conversation,
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleStoreSelectionChanged() {
    if (!mounted) {
      return;
    }

    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    if (_loadedStoreId == selectedStoreId) {
      return;
    }

    setState(() {
      _loadedStoreId = selectedStoreId;
      _conversations = selectedStoreId == null
          ? null
          : widget.repository.findConversations(
        selectedStoreId,
      );
    });
  }

  void _loadForCurrentStore() {
    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    _loadedStoreId = selectedStoreId;
    _conversations = selectedStoreId == null
        ? null
        : widget.repository.findConversations(
      selectedStoreId,
    );
  }

  Future<void> _reload() async {
    final selectedStoreId =
        widget.selectionController.selectedStoreId;

    if (selectedStoreId == null) {
      return;
    }

    final nextFuture =
    widget.repository.findConversations(
      selectedStoreId,
    );

    setState(() {
      _loadedStoreId = selectedStoreId;
      _conversations = nextFuture;
    });

    await nextFuture;
  }

  Future<void> _openConversation(
      SellerConversationSummary conversation,
      ) async {
    final encodedOrderPublicId = Uri.encodeComponent(
      conversation.orderPublicId,
    );

    await context.push(
      '${SellerRoutes.customers}/$encodedOrderPublicId',
    );

    if (!mounted) {
      return;
    }

    await _reload();
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  final SellerConversationSummary conversation;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasUnreadMessage =
        conversation.hasUnreadMessage;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: hasUnreadMessage ? 2 : 1,
      child: InkWell(
        onTap: () async {
          await onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(
            PopqSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor:
                colorScheme.primaryContainer,
                foregroundColor:
                colorScheme.onPrimaryContainer,
                child: Text(
                  _firstCharacter(
                    conversation.customerName,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(
                width: PopqSpacing.md,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            conversation.customerName,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: PopqSpacing.xs,
                        ),
                        Flexible(
                          child: Text(
                            '#${conversation.orderPublicId}',
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: PopqSpacing.xs,
                    ),
                    Text(
                      conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        color: hasUnreadMessage
                            ? colorScheme.onSurface
                            : colorScheme
                            .onSurfaceVariant,
                        fontWeight: hasUnreadMessage
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: PopqSpacing.sm,
              ),
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Text(
                    _relativeTime(
                      conversation.lastMessageAt,
                    ),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      color: hasUnreadMessage
                          ? colorScheme.primary
                          : colorScheme
                          .onSurfaceVariant,
                      fontWeight: hasUnreadMessage
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(
                    height: PopqSpacing.sm,
                  ),
                  AnimatedContainer(
                    duration:
                    const Duration(milliseconds: 180),
                    width: hasUnreadMessage ? 8 : 0,
                    height: hasUnreadMessage ? 8 : 0,
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _firstCharacter(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return '?';
    }

    return String.fromCharCode(
      normalized.runes.first,
    );
  }

  static String _relativeTime(DateTime value) {
    final localValue = value.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localValue);

    if (difference.isNegative ||
        difference.inMinutes < 1) {
      return '방금 전';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    }

    if (difference.inHours < 24 &&
        _isSameDay(now, localValue)) {
      return '${difference.inHours}시간 전';
    }

    if (_isSameDay(now, localValue)) {
      return '${_twoDigits(localValue.hour)}:'
          '${_twoDigits(localValue.minute)}';
    }

    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(
      const Duration(days: 1),
    );

    if (_isSameDay(yesterday, localValue)) {
      return '어제';
    }

    if (now.year == localValue.year) {
      return '${localValue.month}월 '
          '${localValue.day}일';
    }

    return '${localValue.year}.'
        '${_twoDigits(localValue.month)}.'
        '${_twoDigits(localValue.day)}';
  }

  static bool _isSameDay(
      DateTime left,
      DateTime right,
      ) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _NoSelectedStoreView extends StatelessWidget {
  const _NoSelectedStoreView();

  @override
  Widget build(BuildContext context) {
    return const PopqEmptyView(
      icon: Icons.storefront_outlined,
      title: '선택된 사업장이 없어요.',
      description:
      '대시보드에서 고객 문의를 확인할 사업장을 먼저 선택해 주세요.',
    );
  }
}