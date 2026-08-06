import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/seller_router.dart';
import '../orders/seller_order_list_screen.dart';
import '../orders/seller_order_repository.dart';
import '../reviews/seller_review_repository.dart';
import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';
import 'seller_operational_alert_repository.dart';

class SellerNotificationInboxScreen extends StatefulWidget {
  const SellerNotificationInboxScreen({
    required this.repository,
    required this.storeRepository,
    required this.selectionController,
    super.key,
  });

  final SellerOperationalAlertRepository repository;
  final SellerStoreRepository storeRepository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerNotificationInboxScreen> createState() =>
      _SellerNotificationInboxScreenState();
}

class _SellerNotificationInboxScreenState
    extends State<SellerNotificationInboxScreen> {
  late Future<_InboxData> _data;
  Set<int> _activeStoreIds = const {};
  var _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('운영 알림'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '주문'),
              Tab(text: '채팅'),
              Tab(text: '리뷰'),
            ],
          ),
        ),
        body: FutureBuilder<_InboxData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const PopqLoadingView(message: '운영 알림을 불러오고 있어요.');
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return PopqErrorView(
                message: '운영 알림을 불러오지 못했어요.',
                onRetry: _refresh,
              );
            }
            final data = snapshot.requireData;
            return TabBarView(
              children: [
                _AlertList(
                  emptyTitle: '접수 대기 주문이 없어요',
                  onRefresh: _refresh,
                  children: data.alerts.orders
                      .map((order) => _orderTile(order))
                      .toList(),
                ),
                _AlertList(
                  emptyTitle: '읽지 않은 채팅이 없어요',
                  onRefresh: _refresh,
                  children: data.alerts.chats
                      .map((chat) => _chatTile(chat))
                      .toList(),
                ),
                _AlertList(
                  emptyTitle: '답변 대기 리뷰가 없어요',
                  onRefresh: _refresh,
                  children: data.alerts.reviews
                      .map(
                        (review) => _reviewTile(
                          review,
                          data.storeNames[review.storeId] ?? '사업장',
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _orderTile(SellerOrder order) {
    final items = order.items
        .map((item) => '${item.productName} ${item.quantity}개')
        .join(', ');
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.notifications_rounded)),
      title: Text('${order.storeName} · ${formatPopqOrderNumber(order.orderPublicId)}'),
      subtitle: Text(
        '${_dateTime(order.createdAt)}\n${items.isEmpty ? '상품 정보 없음' : items}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _openOrder(order),
    );
  }

  Widget _chatTile(SellerChatAlert chat) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.chat_bubble_rounded)),
      title: Text('${chat.storeName} · ${chat.customerName}'),
      subtitle: Text(
        '${formatPopqOrderNumber(chat.orderPublicId)} · ${_dateTime(chat.lastMessageAt)}\n${chat.lastMessage}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _openChat(chat),
    );
  }

  Widget _reviewTile(SellerReview review, String storeName) {
    final content = review.content?.trim();
    return ListTile(
      leading: CircleAvatar(child: Text('${review.rating}★')),
      title: Text('$storeName · ${review.authorName}'),
      subtitle: Text(
        '${_dateTime(review.createdAt)}\n${content == null || content.isEmpty ? '내용 없는 리뷰' : content}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _openReviews(review.storeId),
    );
  }

  Future<_InboxData> _load() async {
    final serial = ++_requestSerial;
    final results = await Future.wait([
      widget.repository.findAll(limit: 30),
      widget.storeRepository.findAll(),
    ]);
    final alerts = results[0] as SellerOperationalAlerts;
    final stores = results[1] as List<SellerStore>;
    final activeStores = stores.where((store) => store.status == 'ACTIVE');
    if (serial == _requestSerial) {
      _activeStoreIds = activeStores.map((store) => store.storeId).toSet();
    }
    return _InboxData(
      alerts: alerts,
      storeNames: {for (final store in activeStores) store.storeId: store.name},
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    if (mounted) setState(() => _data = next);
    await next;
  }

  Future<void> _openOrder(SellerOrder order) async {
    if (!await _selectStore(order.storeId) || !mounted) return;
    await context.push(
      '${SellerRoutes.orders}/${order.orderPublicId}?storeId=${order.storeId}',
    );
    if (mounted) await _refresh();
  }

  Future<void> _openChat(SellerChatAlert chat) async {
    if (!await _selectStore(chat.storeId) || !mounted) return;
    await context.push(
      '${SellerRoutes.customers}/${Uri.encodeComponent(chat.orderPublicId)}',
    );
    if (mounted) await _refresh();
  }

  Future<void> _openReviews(int storeId) async {
    if (!await _selectStore(storeId) || !mounted) return;
    await context.push('${SellerRoutes.operations}?section=reviews');
    if (mounted) await _refresh();
  }

  Future<bool> _selectStore(int storeId) async {
    if (!_activeStoreIds.contains(storeId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 접근 가능한 사업장을 다시 확인해 주세요.')),
        );
      }
      return false;
    }
    try {
      await widget.selectionController.select(storeId);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사업장 선택을 저장하지 못했어요.')),
        );
      }
      return false;
    }
  }

  String _dateTime(DateTime? value) {
    if (value == null) return '시각 정보 없음';
    final seoul = value.toUtc().add(const Duration(hours: 9));
    return '${seoul.month.toString().padLeft(2, '0')}.${seoul.day.toString().padLeft(2, '0')} '
        '${seoul.hour.toString().padLeft(2, '0')}:${seoul.minute.toString().padLeft(2, '0')}';
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({
    required this.emptyTitle,
    required this.onRefresh,
    required this.children,
  });

  final String emptyTitle;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: PopqSpacing.sm),
        itemCount: children.isEmpty ? 1 : children.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => children.isEmpty
            ? SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.55,
                child: PopqEmptyView(
                  icon: Icons.notifications_none_rounded,
                  title: emptyTitle,
                  description: '아래로 당겨 새로고침할 수 있어요.',
                ),
              )
            : children[index],
      ),
    );
  }
}

class _InboxData {
  const _InboxData({required this.alerts, required this.storeNames});

  final SellerOperationalAlerts alerts;
  final Map<int, String> storeNames;
}
