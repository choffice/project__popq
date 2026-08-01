import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/notifications/customer_notification_repository.dart';
import 'features/notifications/notification_action.dart';
import 'routing/customer_router.dart';

class CustomerRootScreen extends StatefulWidget {
  const CustomerRootScreen({
    required this.location,
    required this.child,
    required this.notificationRepository,
    required this.sessionController,
    super.key,
  });

  final String location;
  final Widget child;
  final CustomerNotificationRepository notificationRepository;
  final SessionController sessionController;

  @override
  State<CustomerRootScreen> createState() =>
      _CustomerRootScreenState();
}

class _CustomerRootScreenState
    extends State<CustomerRootScreen> {
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

  static const _titles = [
    'POPQ',
    '스토어 찾기',
    '주문 내역',
    '마이 POPQ',
    'QR 스캔',
  ];

  // 하단 UI 순서
  // 홈(경로 0)
  // 탐색(경로 1)
  // QR(경로 4)
  // 주문(경로 2)
  // 마이(경로 3)
  static const _uiToRouteIndex = [0, 1, 4, 2, 3];

  DateTime? _lastBackPressedAt;

  @override
  Widget build(BuildContext context) {
    final routeIndex =
    _routeIndexForLocation(widget.location);

    // 실제 경로 인덱스를 하단 UI 인덱스로 변환
    final selectedIndex =
    _uiToRouteIndex.indexOf(routeIndex);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleSystemBack();
      },
      child: PopqAppScaffold(
        title: _titles[routeIndex],
        actions: [
          NotificationAction(
            repository:
            widget.notificationRepository,
            sessionController:
            widget.sessionController,
          ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: (uiIndex) {
          final nextRouteIndex =
          _uiToRouteIndex[uiIndex];

          final nextLocation =
          _locations[nextRouteIndex];

          if (nextLocation == widget.location) {
            return;
          }

          context.go(nextLocation);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon:
            Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon:
            Icon(Icons.manage_search_rounded),
            label: '탐색',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.qr_code_scanner_rounded,
            ),
            selectedIcon: Icon(
              Icons.qr_code_scanner_rounded,
            ),
            label: 'QR',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            selectedIcon: Icon(
              Icons.receipt_long_rounded,
            ),
            label: '주문',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            selectedIcon:
            Icon(Icons.person_rounded),
            label: '마이',
          ),
        ],
        body: widget.child,
      ),
    );
  }

  void _handleSystemBack() {
    // 홈이 아닌 하단 메뉴 화면에서는
    // 앱을 종료하지 않고 홈으로 돌아갑니다.
    if (widget.location != CustomerRoutes.home) {
      _lastBackPressedAt = null;
      context.go(CustomerRoutes.home);
      return;
    }

    final now = DateTime.now();

    final shouldExit =
        _lastBackPressedAt != null &&
            now.difference(_lastBackPressedAt!) <=
                const Duration(seconds: 2);

    // 홈에서 2초 안에 뒤로가기를 다시 누르면 종료합니다.
    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            '한 번 더 누르면 앱이 종료됩니다.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
  }

  int _routeIndexForLocation(String value) {
    final index = _locations.indexWhere(
          (candidate) =>
          value.startsWith(candidate),
    );

    return index < 0 ? 0 : index;
  }
}