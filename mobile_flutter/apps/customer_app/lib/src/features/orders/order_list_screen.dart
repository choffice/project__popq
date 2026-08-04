import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../inquiry/customer_order_message.dart';
import '../inquiry/customer_order_message_repository.dart';
import 'customer_order_repository.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({
    required this.repository,
    required this.messageRepository,
    super.key,
  });

  final CustomerOrderRepository repository;
  final CustomerOrderMessageRepository messageRepository;

  @override
  State<OrderListScreen> createState() {
    return _OrderListScreenState();
  }
}

class _OrderListScreenState extends State<OrderListScreen> {
  late Future<_OrderListData> _data;

  @override
  void initState() {
    super.initState();

    _data = _loadData();
  }

  @override
  void didUpdateWidget(
      covariant OrderListScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.repository != widget.repository ||
        oldWidget.messageRepository !=
            widget.messageRepository) {
      _data = _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OrderListData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const PopqLoadingView(
            message: '주문 내역을 불러오고 있어요.',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '주문 내역을 불러오지 못했습니다.',
            onRetry: _reload,
          );
        }

        final data = snapshot.requireData;

        if (data.orders.isEmpty) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: const CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PopqEmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: '아직 주문 내역이 없어요.',
                    description:
                    '마음에 드는 스토어에서 첫 주문을 시작해 보세요.',
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
            padding: const EdgeInsets.all(
              PopqSpacing.md,
            ),
            itemCount: data.orders.length,
            separatorBuilder: (_, _) {
              return const SizedBox(
                height: PopqSpacing.sm,
              );
            },
            itemBuilder: (context, index) {
              final order = data.orders[index];

              final unreadCount =
                  data.unreadCounts[
                  order.orderPublicId] ??
                      0;

              return _OrderCard(
                order: order,
                unreadCount: unreadCount,
                onOpenDetail: () {
                  _openOrderDetail(order);
                },
                onOpenInquiry: () {
                  _openOrderInquiry(order);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<_OrderListData> _loadData() async {
    final ordersFuture = widget.repository.findAll();

    final unreadCountsFuture =
    widget.messageRepository
        .findUnreadMessageCounts();

    final orders = await ordersFuture;

    final unreadCounts =
    await unreadCountsFuture;

    return _OrderListData(
      orders: orders,
      unreadCounts: {
        for (final item in unreadCounts)
          item.orderPublicId: item.unreadCount,
      },
    );
  }

  Future<void> _reload() async {
    final nextData = _loadData();

    setState(() {
      _data = nextData;
    });

    await nextData;
  }

  Future<void> _openOrderDetail(
      CustomerOrder order,
      ) async {
    await context.push(
      '${CustomerRoutes.orders}/${order.orderPublicId}',
    );

    if (!mounted) {
      return;
    }

    /*
     * 주문 상세 또는 상세에서 열린 문의 화면에서
     * 돌아온 경우 최신 주문 상태와 읽지 않은 답변 수를
     * 다시 불러옵니다.
     */
    await _reload();
  }

  Future<void> _openOrderInquiry(
      CustomerOrder order,
      ) async {
    await context.push(
      CustomerRoutes.orderMessages(
        order.orderPublicId,
      ),
    );

    if (!mounted) {
      return;
    }

    /*
     * 채팅 화면 진입 시 판매자 메시지가 읽음 처리되므로,
     * 화면 복귀 직후 읽지 않은 답변 배지를 다시 조회합니다.
     */
    await _reload();
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.unreadCount,
    required this.onOpenDetail,
    required this.onOpenInquiry,
  });

  final CustomerOrder order;
  final int unreadCount;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenInquiry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          /*
           * 기존 주문 카드 클릭 시 주문 상세로 이동하는
           * 기능을 그대로 유지합니다.
           */
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.md,
              PopqSpacing.md,
              PopqSpacing.sm,
            ),
            leading: CircleAvatar(
              backgroundColor:
              colorScheme.primaryContainer,
              foregroundColor:
              colorScheme.onPrimaryContainer,
              child: const Icon(
                Icons.receipt_long_rounded,
              ),
            ),
            title: Text(
              order.storeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(
                top: PopqSpacing.xs,
              ),
              child: Text(
                '${_statusLabel(order.status)} · '
                    '${order.items.length}개 항목',
              ),
            ),
            trailing: Text(
              _won(order.totalAmount),
              style: theme.textTheme.titleSmall
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            onTap: onOpenDetail,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PopqSpacing.md,
            ),
            child: Divider(
              height: 1,
              color: colorScheme.outlineVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              PopqSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(
                      Icons
                          .assignment_outlined,
                    ),
                    label: const Text(
                      '진행 현황 보기',
                    ),
                  ),
                ),
                const SizedBox(
                  width: PopqSpacing.sm,
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenInquiry,
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _InquiryIcon(
                          unreadCount:
                          unreadCount,
                        ),
                        const SizedBox(
                          width: PopqSpacing.sm,
                        ),
                        const Flexible(
                          child: Text(
                            '문의하기',
                            overflow:
                            TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InquiryIcon extends StatelessWidget {
  const _InquiryIcon({
    required this.unreadCount,
  });

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return SizedBox(
      width: unreadCount > 0 ? 30 : 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            top: 2,
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius:
                  BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  unreadCount > 99
                      ? '99+'
                      : unreadCount.toString(),
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderListData {
  const _OrderListData({
    required this.orders,
    required this.unreadCounts,
  });

  final List<CustomerOrder> orders;
  final Map<String, int> unreadCounts;
}

String _statusLabel(String status) {
  return switch (status) {
    'CREATED' => '결제 대기',
    'PLACED' => '주문 접수 대기',
    'ACCEPTED' => '주문 접수',
    'PREPARING' => '준비 중',
    'READY' => '준비 완료',
    'COMPLETED' => '완료',
    'REJECTED' => '거절',
    'CANCELED' => '취소',
    'EXPIRED' => '만료',
    _ => status,
  };
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0;
  index < digits.length;
  index++) {
    if (index > 0 &&
        (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return '$buffer원';
}