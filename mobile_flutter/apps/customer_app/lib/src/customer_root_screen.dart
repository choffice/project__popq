import 'dart:async';

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
  // 실제 라우트 순서
  //
  // 0 홈
  // 1 탐색
  // 2 찜
  // 3 마이
  // 4 QR
  static const List<String> _locations = [
    CustomerRoutes.home,
    CustomerRoutes.discover,
    CustomerRoutes.favorites,
    CustomerRoutes.profile,
    CustomerRoutes.qrScanner,
  ];

  static const List<String> _titles = [
    'POPQ',
    '스토어 찾기',
    '찜한 매장',
    '마이 POPQ',
    'QR 스캔',
  ];

  // 하단 내비게이션 UI 순서
  //
  // 홈   -> 실제 라우트 0
  // 탐색 -> 실제 라우트 1
  // QR   -> 실제 라우트 4
  // 찜   -> 실제 라우트 2
  // 마이 -> 실제 라우트 3
  static const List<int> _uiToRouteIndex = [
    0,
    1,
    4,
    2,
    3,
  ];

  static const Duration _exitConfirmDuration =
  Duration(seconds: 2);

  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();

    unawaited(
      SystemNavigator.setFrameworkHandlesBack(true),
    );
  }

  @override
  void didUpdateWidget(
      CustomerRootScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.location != widget.location) {
      _lastBackPressedAt = null;
    }
  }

  @override
  void dispose() {
    unawaited(
      SystemNavigator.setFrameworkHandlesBack(false),
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeIndex = _routeIndexForLocation(
      widget.location,
    );

    final selectedIndex = _uiToRouteIndex.indexOf(
      routeIndex,
    );

    return BackButtonListener(
      onBackButtonPressed: _handleRootBackButtonPressed,
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (
            didPop,
            result,
            ) {
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

            _lastBackPressedAt = null;

            context.go(nextLocation);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons.home_outlined,
              ),
              selectedIcon: Icon(
                Icons.home_rounded,
              ),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.search_rounded,
              ),
              selectedIcon: Icon(
                Icons.manage_search_rounded,
              ),
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
                Icons.favorite_border_rounded,
              ),
              selectedIcon: Icon(
                Icons.favorite_rounded,
              ),
              label: '찜',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline_rounded,
              ),
              selectedIcon: Icon(
                Icons.person_rounded,
              ),
              label: '마이',
            ),
          ],
          body: widget.child,
        ),
      ),
    );
  }

  Future<bool> _handleRootBackButtonPressed() {
    _handleSystemBack();

    return Future<bool>.value(true);
  }

  void _handleSystemBack() {
    if (!mounted) {
      return;
    }

    // 홈이 아닌 하단 탭에서는 앱을 종료하지 않고 홈으로 이동합니다.
    if (widget.location != CustomerRoutes.home) {
      _lastBackPressedAt = null;

      context.go(
        CustomerRoutes.home,
      );

      return;
    }

    final now = DateTime.now();
    final previousPressedAt = _lastBackPressedAt;

    final shouldExit =
        previousPressedAt != null &&
            now.difference(previousPressedAt) <=
                _exitConfirmDuration;

    // 홈에서 2초 안에 두 번째로 누른 경우에만 종료합니다.
    if (shouldExit) {
      _lastBackPressedAt = null;

      unawaited(
        SystemNavigator.pop(),
      );

      return;
    }

    // 홈에서 첫 번째 뒤로가기입니다.
    _lastBackPressedAt = now;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            '한 번 더 누르면 앱이 종료됩니다.',
          ),
          duration: _exitConfirmDuration,
        ),
      );
  }

  int _routeIndexForLocation(
      String value,
      ) {
    final index = _locations.indexWhere(
          (candidate) => value.startsWith(candidate),
    );

    return index < 0 ? 0 : index;
  }
}