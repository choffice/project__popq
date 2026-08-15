import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/common/theme_mode_toggle.dart';
import 'features/inquiry/customer_order_message_repository.dart';
import 'features/notifications/customer_notification_repository.dart';
import 'features/notifications/notification_action.dart';
import 'realtime/customer_realtime_scope.dart';
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
  State<CustomerRootScreen> createState() {
    return _CustomerRootScreenState();
  }
}

class _CustomerRootScreenState extends State<CustomerRootScreen>
    with WidgetsBindingObserver {
  // 실제 라우트 순서
  //
  // 0 홈
  // 1 탐색
  // 2 찜
  // 3 마이
  // 4 QR
  static const List<String> _locations = <String>[
    CustomerRoutes.home,
    CustomerRoutes.discover,
    CustomerRoutes.favorites,
    CustomerRoutes.profile,
    CustomerRoutes.qrScanner,
  ];

  static const List<String> _titles = <String>[
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
  static const List<int> _uiToRouteIndex = <int>[
    0,
    1,
    4,
    2,
    3,
  ];

  static const Duration _unreadPollingInterval = Duration(
    seconds: 3,
  );

  Timer? _unreadPollingTimer;
  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _customerChatSubscription;

  var _unreadMessageCount = 0;
  var _unreadRequestInProgress = false;
  var _requestGeneration = 0;
  var _observedConnectionEpoch = 0;
  var _isAppActive = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed;

    widget.sessionController.addListener(
      _handleSessionChanged,
    );

    _scheduleUnreadRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextRealtimeClient = CustomerRealtimeScope.of(context);

    if (identical(_realtimeClient, nextRealtimeClient)) {
      return;
    }

    _customerChatSubscription?.cancel();
    _customerChatSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    _realtimeClient = nextRealtimeClient;
    _observedConnectionEpoch = nextRealtimeClient.connectionEpoch;

    nextRealtimeClient.addListener(
      _handleRealtimeClientChanged,
    );

    _ensureCustomerChatSubscription();
    _syncUnreadPollingWithRealtime();
    _scheduleUnreadRefresh();
  }

  @override
  void didUpdateWidget(
      covariant CustomerRootScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.location != widget.location) {
      // 주문 채팅에서 하단 화면으로 돌아왔을 때
      // 읽음 처리 결과를 즉시 반영합니다.
      _scheduleUnreadRefresh();
    }

    if (oldWidget.sessionController != widget.sessionController) {
      oldWidget.sessionController.removeListener(
        _handleSessionChanged,
      );

      widget.sessionController.addListener(
        _handleSessionChanged,
      );

      _requestGeneration++;
      _customerChatSubscription?.cancel();
      _customerChatSubscription = null;
      _resetUnreadMessageCount();
      _ensureCustomerChatSubscription();
      _syncUnreadPollingWithRealtime();
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

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _ensureCustomerChatSubscription();
        _syncUnreadPollingWithRealtime();

        unawaited(
          _refreshUnreadMessageCount(),
        );

        return;

      case AppLifecycleState.inactive:
        _isAppActive = false;
        _stopUnreadPolling();
        return;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isAppActive = false;
        _stopUnreadPolling();
        return;
    }
  }

  @override
  void dispose() {
    _requestGeneration++;

    _stopUnreadPolling();

    _customerChatSubscription?.cancel();
    _customerChatSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );
    _realtimeClient = null;

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
      actions: <Widget>[
        if (widget.themeController != null)
          ThemeModeToggle(
            controller: widget.themeController!,
          ),
        NotificationAction(
          repository: widget.notificationRepository,
          sessionController: widget.sessionController,
        ),
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: (int uiIndex) {
        final nextRouteIndex = _uiToRouteIndex[uiIndex];
        final nextLocation = _locations[nextRouteIndex];

        unawaited(
          _refreshUnreadMessageCount(),
        );

        if (nextLocation == widget.location) {
          return;
        }

        context.go(nextLocation);
      },
      destinations: <NavigationDestination>[
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
            icon: Icons.person_outline_rounded,
            unreadCount: _unreadMessageCount,
          ),
          selectedIcon: _MyNavigationIcon(
            icon: Icons.person_rounded,
            unreadCount: _unreadMessageCount,
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

    if (!widget.sessionController.isSignedIn) {
      _customerChatSubscription?.cancel();
      _customerChatSubscription = null;
      _stopUnreadPolling();
      _resetUnreadMessageCount();
      return;
    }

    _ensureCustomerChatSubscription();
    _syncUnreadPollingWithRealtime();

    unawaited(
      _refreshUnreadMessageCount(),
    );
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) {
      return;
    }

    final realtimeClient = _realtimeClient;

    if (realtimeClient == null) {
      return;
    }

    if (_observedConnectionEpoch != realtimeClient.connectionEpoch) {
      _observedConnectionEpoch = realtimeClient.connectionEpoch;

      // 재연결 직후 끊긴 동안 놓친 이벤트를 REST로 한 번 복구합니다.
      unawaited(
        _refreshUnreadMessageCount(),
      );
    }

    _syncUnreadPollingWithRealtime();
  }

  void _handleCustomerChatEvent(
      PopqRealtimeEvent event,
      ) {
    if (!mounted) {
      return;
    }

    final shouldRefresh =
        event.isMessageRead ||
            (event.isMessageCreated &&
                event.message?.sentBySeller == true);

    if (!shouldRefresh) {
      return;
    }

    unawaited(
      _refreshUnreadMessageCount(),
    );
  }

  void _handleCustomerChatError(
      Object error,
      ) {
    debugPrint(
      '구매자 전역 채팅 이벤트를 처리하지 못했습니다: $error',
    );
  }

  void _ensureCustomerChatSubscription() {
    if (!widget.sessionController.isSignedIn ||
        _customerChatSubscription != null) {
      return;
    }

    final realtimeClient = _realtimeClient;

    if (realtimeClient == null) {
      return;
    }

    _customerChatSubscription =
        realtimeClient.subscribeToCustomerChat(
          onEvent: _handleCustomerChatEvent,
          onError: _handleCustomerChatError,
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

  void _syncUnreadPollingWithRealtime() {
    if (!_isAppActive ||
        !widget.sessionController.isSignedIn) {
      _stopUnreadPolling();
      return;
    }

    if (_realtimeClient?.isConnected == true) {
      _stopUnreadPolling();
      return;
    }

    _startUnreadPolling();
  }

  void _startUnreadPolling() {
    if (!_isAppActive ||
        !widget.sessionController.isSignedIn ||
        _realtimeClient?.isConnected == true ||
        (_unreadPollingTimer?.isActive ?? false)) {
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

  Future<void> _refreshUnreadMessageCount() async {
    if (!mounted || _unreadRequestInProgress) {
      return;
    }

    if (!widget.sessionController.isSignedIn) {
      _resetUnreadMessageCount();
      return;
    }

    final generation = _requestGeneration;

    _unreadRequestInProgress = true;

    try {
      final unreadCounts = await widget.orderMessageRepository
          .findUnreadMessageCounts();

      final totalUnreadCount = unreadCounts.fold<int>(
        0,
            (int total, item) {
          return total + item.unreadCount;
        },
      );

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      if (_unreadMessageCount == totalUnreadCount) {
        return;
      }

      setState(() {
        _unreadMessageCount = totalUnreadCount;
      });
    } catch (error, stackTrace) {
      // 자동 조회가 잠시 실패해도 기존 배지는 유지하고
      // 다음 실시간 이벤트 또는 폴링 주기에 다시 시도합니다.
      debugPrint(
        '읽지 않은 판매자 답변 수를 불러오지 못했습니다: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _unreadRequestInProgress = false;
    }
  }

  void _resetUnreadMessageCount() {
    if (!mounted || _unreadMessageCount == 0) {
      return;
    }

    setState(() {
      _unreadMessageCount = 0;
    });
  }

  // "마이" 탭 안에서 열리는 하위 화면들입니다.
  // 이 화면들에 있을 때도 하단 탭은 "마이"로 유지되어야 합니다.
  static const List<String> _profileSubRoutes = <String>[
    CustomerRoutes.orders,
    CustomerRoutes.myInfo,
    CustomerRoutes.myReviews,
    CustomerRoutes.pointHistory,
    CustomerRoutes.visitHistory,
    CustomerRoutes.notificationSettings,
  ];

  int _routeIndexForLocation(
      String value,
      ) {
    if (_profileSubRoutes.any(
          (String candidate) => value.startsWith(candidate),
    )) {
      return _locations.indexOf(CustomerRoutes.profile);
    }

    final index = _locations.indexWhere(
          (String candidate) => value.startsWith(candidate),
    );

    return index < 0 ? 0 : index;
  }
}

class _MyNavigationIcon extends StatelessWidget {
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

    final colorScheme = Theme.of(context).colorScheme;

    final badgeText = unreadCount > 99
        ? '99+'
        : unreadCount.toString();

    return SizedBox(
      width: 38,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Icon(icon),
          Positioned(
            top: -5,
            right: -3,
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
                borderRadius: BorderRadius.circular(999),
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