import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';
import 'package:popq_app_core/popq_app_core.dart';

import 'features/notifications/customer_notification_repository.dart';
import 'features/notifications/notification_action.dart';
import 'routing/customer_router.dart';

class CustomerRootScreen extends StatelessWidget {
  const CustomerRootScreen({
    required this.location,
    required this.child,
    required this.notificationRepository,
    required this.sessionController,
    super.key,
  });

  // 실제 경로 순서
  // 0 홈
  // 1 탐색
  // 2 주문
  // 3 마이
  // 4 QR
  static const _locations = [
    CustomerRoutes.home,
    CustomerRoutes.discover,
    CustomerRoutes.orders,
    CustomerRoutes.profile,
    CustomerRoutes.qrScanner,
  ];
  static const _titles = ['POPQ', '스토어 찾기', '주문 내역', '마이 POPQ', 'QR 스캔'];

  // 하단 UI 순서
  // 홈(경로 0)
  // 탐색(경로 1)
  // QR(경로 4)
  static const _uiToRouteIndex = [0, 1, 4, 2, 3];

  final String location;
  final Widget child;
  final CustomerNotificationRepository notificationRepository;
  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final routeIndex = _routeIndexForLocation(location);

    // 실제 경로 인덱스를 하단 UI 인덱스로 변환
    final selectedIndex = _uiToRouteIndex.indexOf(routeIndex);

    return PopqAppScaffold(
      title: _titles[routeIndex],
      actions: [
        NotificationAction(
          repository: notificationRepository,
          sessionController: sessionController,
        ),
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: (uiIndex) {
        final routeIndex = _uiToRouteIndex[uiIndex];
        context.go(_locations[routeIndex]);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: '홈',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_rounded),
          selectedIcon: Icon(Icons.manage_search_rounded),
          label: '탐색',
        ),
        NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_rounded),
          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
          label: 'QR',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: '주문',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: '마이',
        ),
      ],
      body: child,
    );
  }

  int _routeIndexForLocation(String value) {
    final index = _locations.indexWhere(
      (candidate) => value.startsWith(candidate),
    );

    return index < 0 ? 0 : index;
  }
}
