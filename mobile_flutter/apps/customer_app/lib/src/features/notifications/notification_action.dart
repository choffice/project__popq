import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../../routing/customer_router.dart';
import 'customer_notification_repository.dart';

class NotificationAction extends StatefulWidget {
  const NotificationAction({
    required this.repository,
    required this.sessionController,
    super.key,
  });

  final CustomerNotificationRepository repository;
  final SessionController sessionController;

  @override
  State<NotificationAction> createState() => _NotificationActionState();
}

class _NotificationActionState extends State<NotificationAction> {
  Future<int>? _unreadCount;

  @override
  void initState() {
    super.initState();
    widget.sessionController.addListener(_onSessionChanged);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant NotificationAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionController != widget.sessionController) {
      oldWidget.sessionController.removeListener(_onSessionChanged);
      widget.sessionController.addListener(_onSessionChanged);
      _refresh();
    }
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: IconButton(
            tooltip: '알림',
            onPressed: _openNotifications,
            icon: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }

  void _refresh() {
    _unreadCount = widget.sessionController.isSignedIn
        ? widget.repository.unreadCount()
        : null;
  }

  void _onSessionChanged() {
    if (mounted) setState(_refresh);
  }

  Future<void> _openNotifications() async {
    await context.push(CustomerRoutes.notifications);
    if (!mounted) return;
    setState(_refresh);
  }
}
