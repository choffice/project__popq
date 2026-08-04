import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/common/theme_mode_toggle.dart';
import 'features/inquiry/customer_order_message_repository.dart';
import 'features/notifications/customer_notification_repository.dart';
import 'features/notifications/notification_action.dart';
import 'routing/customer_router.dart';

class CustomerRootScreen extends StatefulWidget {
  const CustomerRootScreen({
    required this.location,
    required this.child,
    required this.notificationRepository,
    required this.orderMessageRepository,
    required this.sessionController,
    this.themeController,
    super.key,
  });

  final String location;
  final Widget child;
  final CustomerNotificationRepository notificationRepository;
  final CustomerOrderMessageRepository orderMessageRepository;
  final SessionController sessionController;
  final PopqThemeController? themeController;

  @override
  State<CustomerRootScreen> createState() =>
      _CustomerRootScreenState();
}

class _CustomerRootScreenState
    extends State<CustomerRootScreen>
    with WidgetsBindingObserver {
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

  static const Duration _unreadPollingInterval =
  Duration(seconds: 3);

  Timer? _unreadPollingTimer;

  var _unreadMessageCount = 0;
  var _unreadRequestInProgress = false;
  var _requestGeneration = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    widget.sessionController.addListener(
      _handleSessionChanged,
    );

    _startUnreadPolling();
    _scheduleUnreadRefresh();
  }

  @override
  void didUpdateWidget(
      covariant CustomerRootScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.location != widget.location) {
      /*
       * 주문 채팅에서 하단 화면으로 돌아왔을 때
       * 읽음 처리 결과를 즉시 반영합니다.
       */
      _scheduleUnreadRefresh();
    }

    if (oldWidget.sessionController !=
        widget.sessionController) {
      oldWidget.sessionController.removeListener(
        _handleSessionChanged,
      );

      widget.sessionController.addListener(
        _handleSessionChanged,
      );

      _requestGeneration++;
      _resetUnreadMessageCount();
      _scheduleUnreadRefresh();
    }

    if (oldWidget.orderMessageRepository !=
        widget.orderMessageRepository) {
      _requestGeneration++;
      _scheduleUnreadRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _startUnreadPolling();

      unawaited(
        _refreshUnreadMessageCount(),
      );

      return;
    }

    /*
     * 앱이 백그라운드에 있을 때는
     * 불필요한 REST 요청을 중지합니다.
     */
    _stopUnreadPolling();
  }

  @override
  void dispose() {
    _requestGeneration++;

    _stopUnreadPolling();

    WidgetsBinding.instance.removeObserver(this);

    widget.sessionController.removeListener(
      _handleSessionChanged,
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

    return PopqAppScaffold(
      title: _titles[routeIndex],
      actions: [
        if (widget.themeController != null)
          ThemeModeToggle(
            controller:
            widget.themeController!,
          ),
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

        unawaited(
          _refreshUnreadMessageCount(),
        );

        if (nextLocation == widget.location) {
          return;
        }

        context.go(nextLocation);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(
            Icons.home_outlined,
          ),
          selectedIcon: Icon(
            Icons.home_rounded,
          ),
          label: '홈',
        ),
        const NavigationDestination(
          icon: Icon(
            Icons.search_rounded,
          ),
          selectedIcon: Icon(
            Icons.manage_search_rounded,
          ),
          label: '탐색',
        ),
        const NavigationDestination(
          icon: Icon(
            Icons.qr_code_scanner_rounded,
          ),
          selectedIcon: Icon(
            Icons.qr_code_scanner_rounded,
          ),
          label: 'QR',
        ),
        const NavigationDestination(
          icon: Icon(
            Icons.favorite_border_rounded,
          ),
          selectedIcon: Icon(
            Icons.favorite_rounded,
          ),
          label: '찜',
        ),
        NavigationDestination(
          icon: _MyNavigationIcon(
            icon:
            Icons.person_outline_rounded,
            unreadCount:
            _unreadMessageCount,
          ),
          selectedIcon: _MyNavigationIcon(
            icon: Icons.person_rounded,
            unreadCount:
            _unreadMessageCount,
          ),
          label: '마이',
        ),
      ],
      body: widget.child,
    );
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }

    _requestGeneration++;

    // 마이페이지에서 push로 들어온 찜한 이벤트 화면은 홈이 아닌
    // 이전 화면(마이페이지)으로 돌아갑니다.
    if (widget.location == CustomerRoutes.favorites &&
        context.canPop()) {
      context.pop();

      return;
    }

    // 홈이 아닌 하단 탭에서는 앱을 종료하지 않고 홈으로 이동합니다.
    if (widget.location != CustomerRoutes.home) {
      context.go(
        CustomerRoutes.home,
      );
    }

    if (!widget.sessionController.isSignedIn) {
      _resetUnreadMessageCount();
      return;
    }

    unawaited(
      _refreshUnreadMessageCount(),
    );
  }

  void _scheduleUnreadRefresh() {
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (!mounted) {
          return;
        }

        unawaited(
          _refreshUnreadMessageCount(),
        );
      },
    );
  }

  void _startUnreadPolling() {
    if (_unreadPollingTimer?.isActive ??
        false) {
      return;
    }

    _unreadPollingTimer = Timer.periodic(
      _unreadPollingInterval,
          (_) {
        unawaited(
          _refreshUnreadMessageCount(),
        );
      },
    );
  }

  void _stopUnreadPolling() {
    _unreadPollingTimer?.cancel();
    _unreadPollingTimer = null;
  }

  Future<void>
  _refreshUnreadMessageCount() async {
    if (!mounted ||
        _unreadRequestInProgress) {
      return;
    }

    if (!widget.sessionController.isSignedIn) {
      _resetUnreadMessageCount();
      return;
    }

    final generation = _requestGeneration;

    _unreadRequestInProgress = true;

    try {
      final unreadCounts =
      await widget.orderMessageRepository
          .findUnreadMessageCounts();

      final totalUnreadCount =
      unreadCounts.fold<int>(
        0,
            (
            total,
            item,
            ) {
          return total + item.unreadCount;
        },
      );

      if (!mounted ||
          generation != _requestGeneration) {
        return;
      }

      if (_unreadMessageCount ==
          totalUnreadCount) {
        return;
      }

      setState(() {
        _unreadMessageCount =
            totalUnreadCount;
      });
    } catch (error, stackTrace) {
      /*
       * 자동 조회가 잠시 실패해도
       * 기존 배지는 유지하고 다음 주기에 재시도합니다.
       */
      debugPrint(
        '읽지 않은 판매자 답변 수를 '
            '불러오지 못했습니다: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _unreadRequestInProgress = false;
    }
  }

  void _resetUnreadMessageCount() {
    if (!mounted ||
        _unreadMessageCount == 0) {
      return;
    }

    setState(() {
      _unreadMessageCount = 0;
    });
  }

  int _routeIndexForLocation(
      String value,
      ) {
    final index = _locations.indexWhere(
          (candidate) =>
          value.startsWith(candidate),
    );

    return index < 0 ? 0 : index;
  }
}

class _MyNavigationIcon
    extends StatelessWidget {
  const _MyNavigationIcon({
    required this.icon,
    required this.unreadCount,
  });

  final IconData icon;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) {
      return Icon(icon);
    }

    final colorScheme =
        Theme.of(context).colorScheme;

    final badgeText = unreadCount > 99
        ? '99+'
        : unreadCount.toString();

    return SizedBox(
      width: 38,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon),
          Positioned(
            top: -5,
            right: -3,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              padding:
              const EdgeInsets.symmetric(
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
                badgeText,
                style: TextStyle(
                  color: colorScheme.onError,
                  fontSize: 9,
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
