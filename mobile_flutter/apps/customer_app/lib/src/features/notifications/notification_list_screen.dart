import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../notifications/customer_app_badge_service.dart';
import '../../routing/customer_router.dart';
import 'customer_notification_repository.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({required this.repository, super.key});

  final CustomerNotificationRepository repository;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late Future<List<CustomerNotification>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = widget.repository.findAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: FutureBuilder<List<CustomerNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const PopqLoadingView(message: '알림을 불러오고 있어요.');
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return PopqErrorView(message: '알림을 불러오지 못했어요.', onRetry: _reload);
          }
          final notifications = snapshot.requireData;
          if (notifications.isEmpty) {
            return const Center(
              child: PopqEmptyView(
                icon: Icons.notifications_none_rounded,
                title: '아직 알림이 없어요.',
                description: '주문 상태가 바뀌면 여기에서 알려드릴게요.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(PopqSpacing.md),
              itemCount: notifications.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PopqSpacing.sm),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Card(
                  color: notification.read
                      ? null
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: Icon(
                      notification.read
                          ? Icons.notifications_outlined
                          : Icons.notifications_active_rounded,
                    ),
                    title: Text(notification.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification.message),
                        const SizedBox(height: PopqSpacing.xs),
                        Text(_dateLabel(notification.occurredAt)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(notification),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(CustomerNotification notification) async {
    try {
      if (!notification.read) {
        await widget.repository.markRead(
          notification.notificationId,
        );

        try {
          final unreadCount =
          await widget.repository.unreadCount();

          await CustomerAppBadgeService.updateBadge(
            unreadCount,
          );
        } catch (_) {
          // 배지 동기화 실패가 알림 열기를 막지 않도록 합니다.
        }
      }
      if (!mounted) return;
      if (notification.targetType == 'ORDER' &&
          notification.targetId.isNotEmpty) {
        context.push(
          '${CustomerRoutes.orders}/${Uri.encodeComponent(notification.targetId)}',
        );
        return;
      }
      if (notification.targetType == 'STORE' &&
          notification.targetId.isNotEmpty) {
        context.push(
          '${CustomerRoutes.stores}/${Uri.encodeComponent(notification.targetId)}',
        );
        return;
      }
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림을 열지 못했어요.')));
    }
  }

  void _reload() {
    setState(() => _notifications = widget.repository.findAll());
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}.${twoDigits(local.month)}.${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
