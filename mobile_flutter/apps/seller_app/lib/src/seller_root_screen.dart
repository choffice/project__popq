import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/common/theme_mode_toggle.dart';
import 'features/customers/seller_customer_repository.dart';
import 'features/stores/seller_store_repository.dart';
import 'features/stores/seller_store_selection_controller.dart';
import 'realtime/seller_realtime_scope.dart';
import 'routing/seller_router.dart';

class SellerRootScreen extends StatefulWidget {
  const SellerRootScreen({
    required this.location,
    required this.onSignOut,
    required this.child,
    this.customerRepository,
    this.storeRepository,
    this.storeSelectionController,
    this.themeController,
    super.key,
  });

  final String location;
  final Future<void> Function() onSignOut;
  final Widget child;

  final SellerCustomerRepository? customerRepository;
  final SellerStoreRepository? storeRepository;
  final SellerStoreSelectionController? storeSelectionController;
  final PopqThemeController? themeController;

  @override
  State<SellerRootScreen> createState() {
    return _SellerRootScreenState();
  }
}

class _SellerRootScreenState extends State<SellerRootScreen>
    with WidgetsBindingObserver {
  static const List<String> _locations = [
    SellerRoutes.dashboard,
    SellerRoutes.operations,
    SellerRoutes.orders,
    SellerRoutes.customers,
    SellerRoutes.my,
  ];

  static const List<String> _titles = [
    '대시보드',
    '운영',
    '주문 관리',
    '고객',
    '마이',
  ];

  static const Duration _unreadPollingInterval = Duration(
    seconds: 3,
  );

  static const int _maximumRememberedEventIds = 200;

  int _customerUnreadCount = 0;
  int _operationalAlertCount = 0;
  int _unreadRequestSerial = 0;
  int _operationalAlertRequestSerial = 0;
  int _lastConnectionEpoch = 0;

  Timer? _unreadPollingTimer;

  bool _unreadRequestInProgress = false;
  bool _operationalAlertRequestInProgress = false;
  bool _operationalAlertRefreshPending = false;
  bool _isAppActive = true;

  PopqRealtimeClient? _realtimeClient;
  PopqRealtimeSubscription? _storeChatSubscription;

  final Set<String> _rememberedEventIds = <String>{};
  final List<String> _rememberedEventIdOrder = <String>[];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed;

    widget.storeSelectionController?.addListener(
      _handleStoreSelectionChanged,
    );

    _scheduleUnreadRefresh();
    _scheduleOperationalAlertRefresh();
    _startUnreadPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextRealtimeClient = SellerRealtimeScope.maybeOf(
      context,
    );

    if (identical(_realtimeClient, nextRealtimeClient)) {
      return;
    }

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    _storeChatSubscription?.cancel();
    _storeChatSubscription = null;

    _realtimeClient = nextRealtimeClient;
    _lastConnectionEpoch =
        nextRealtimeClient?.connectionEpoch ?? 0;

    nextRealtimeClient?.addListener(
      _handleRealtimeClientChanged,
    );

    _subscribeToSelectedStore();
    _updateUnreadPollingForConnection();
  }

  @override
  void didUpdateWidget(
    covariant SellerRootScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.storeSelectionController !=
        widget.storeSelectionController) {
      oldWidget.storeSelectionController?.removeListener(
        _handleStoreSelectionChanged,
      );

      widget.storeSelectionController?.addListener(
        _handleStoreSelectionChanged,
      );

      _resetUnreadCount();
      _subscribeToSelectedStore();
    }

    if (oldWidget.customerRepository !=
        widget.customerRepository) {
      _resetUnreadCount();
    }

    if (oldWidget.storeRepository != widget.storeRepository) {
      _operationalAlertRequestSerial++;
    }

    _scheduleUnreadRefresh();
    _scheduleOperationalAlertRefresh();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _subscribeToSelectedStore();
        _updateUnreadPollingForConnection();

        unawaited(
          _refreshCustomerUnreadCount(),
        );
        unawaited(_refreshOperationalAlertCount());

        return;

      case AppLifecycleState.inactive:
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
    _unreadRequestSerial++;
    _operationalAlertRequestSerial++;

    _stopUnreadPolling();

    _storeChatSubscription?.cancel();
    _storeChatSubscription = null;

    _realtimeClient?.removeListener(
      _handleRealtimeClientChanged,
    );

    WidgetsBinding.instance.removeObserver(this);

    widget.storeSelectionController?.removeListener(
      _handleStoreSelectionChanged,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForLocation(
      widget.location,
    );

    return PopqAppScaffold(
      title: _titles[selectedIndex],
      actions: [
        if (widget.location != SellerRoutes.dashboard)
          IconButton(
            tooltip: '사업장 전환',
            onPressed: () {
              context.go(
                SellerRoutes.dashboard,
              );
            },
            icon: const Icon(
              Icons.swap_horiz_rounded,
            ),
          ),
        if (widget.themeController != null)
          ThemeModeToggle(
            controller: widget.themeController!,
          ),
        IconButton(
          tooltip: '운영 알림',
          onPressed: () async {
            await context.push(SellerRoutes.notifications);
            if (mounted) await _refreshOperationalAlertCount();
          },
          icon: _OperationalNotificationIcon(
            alertCount: _operationalAlertCount,
          ),
        ),
        IconButton(
          tooltip: '로그아웃',
          onPressed: () {
            _signOut(context);
          },
          icon: const Icon(
            Icons.logout_rounded,
          ),
        ),
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        unawaited(
          _refreshCustomerUnreadCount(),
        );
        unawaited(_refreshOperationalAlertCount());

        final nextLocation = _locations[index];

        if (nextLocation == widget.location) {
          return;
        }

        context.go(nextLocation);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(
            Icons.business_outlined,
          ),
          selectedIcon: Icon(
            Icons.business_rounded,
          ),
          label: '대시보드',
        ),
        const NavigationDestination(
          icon: Icon(
            Icons.tune_outlined,
          ),
          selectedIcon: Icon(
            Icons.tune_rounded,
          ),
          label: '운영',
        ),
        const NavigationDestination(
          icon: Icon(
            Icons.notifications_none_rounded,
          ),
          selectedIcon: Icon(
            Icons.notifications_rounded,
          ),
          label: '주문',
        ),
        NavigationDestination(
          icon: _CustomerNavigationIcon(
            icon: Icons.forum_outlined,
            unreadCount: _customerUnreadCount,
          ),
          selectedIcon: _CustomerNavigationIcon(
            icon: Icons.forum_rounded,
            unreadCount: _customerUnreadCount,
          ),
          label: '고객',
        ),
        const NavigationDestination(
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
    );
  }

  void _handleStoreSelectionChanged() {
    _resetUnreadCount();
    _subscribeToSelectedStore();

    unawaited(
      _refreshCustomerUnreadCount(),
    );
    unawaited(_refreshOperationalAlertCount());
  }

  void _handleRealtimeClientChanged() {
    if (!mounted) {
      return;
    }

    final realtimeClient = _realtimeClient;

    if (realtimeClient == null) {
      _updateUnreadPollingForConnection();
      return;
    }

    final connectionEpoch = realtimeClient.connectionEpoch;

    if (realtimeClient.isConnected &&
        connectionEpoch != _lastConnectionEpoch) {
      _lastConnectionEpoch = connectionEpoch;

      unawaited(
        _refreshCustomerUnreadCount(),
      );
    }

    _updateUnreadPollingForConnection();
  }

  void _subscribeToSelectedStore() {
    _storeChatSubscription?.cancel();
    _storeChatSubscription = null;

    final realtimeClient = _realtimeClient;
    final storeId =
        widget.storeSelectionController?.selectedStoreId;

    if (realtimeClient == null || storeId == null) {
      return;
    }

    _storeChatSubscription = realtimeClient.subscribeToStoreChat(
      storeId: storeId,
      onEvent: _handleStoreChatEvent,
      onError: (error) {
        debugPrint(
          '판매자 사업장 채팅 구독 오류: $error',
        );
      },
    );
  }

  void _handleStoreChatEvent(
    PopqRealtimeEvent event,
  ) {
    if (!mounted || !_rememberEvent(event.eventId)) {
      return;
    }

    final selectedStoreId =
        widget.storeSelectionController?.selectedStoreId;

    if (selectedStoreId == null ||
        event.storeId != selectedStoreId) {
      return;
    }

    unawaited(
      _refreshCustomerUnreadCount(),
    );
  }

  bool _rememberEvent(String eventId) {
    if (!_rememberedEventIds.add(eventId)) {
      return false;
    }

    _rememberedEventIdOrder.add(eventId);

    if (_rememberedEventIdOrder.length >
        _maximumRememberedEventIds) {
      final removedEventId =
          _rememberedEventIdOrder.removeAt(0);

      _rememberedEventIds.remove(removedEventId);
    }

    return true;
  }

  void _scheduleUnreadRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(
        _refreshCustomerUnreadCount(),
      );
    });
  }

  void _scheduleOperationalAlertRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshOperationalAlertCount());
    });
  }

  Future<void> _refreshOperationalAlertCount() async {
    if (_operationalAlertRequestInProgress) {
      _operationalAlertRefreshPending = true;
      return;
    }
    final repository = widget.storeRepository;
    final requestSerial = ++_operationalAlertRequestSerial;
    if (repository == null) return;
    _operationalAlertRequestInProgress = true;
    try {
      final summaries = await repository.findDashboardSummaries();
      final count = summaries.fold<int>(
        0,
        (total, summary) =>
            total +
            summary.waitingOrderCount +
            summary.unreadChatCount +
            summary.unansweredReviewCount,
      );
      if (!mounted || requestSerial != _operationalAlertRequestSerial) return;
      if (_operationalAlertCount != count) {
        setState(() => _operationalAlertCount = count);
      }
    } catch (error, stackTrace) {
      debugPrint('운영 알림 개수를 불러오지 못했습니다: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _operationalAlertRequestInProgress = false;
      if (_operationalAlertRefreshPending && mounted) {
        _operationalAlertRefreshPending = false;
        unawaited(_refreshOperationalAlertCount());
      }
    }
  }

  void _updateUnreadPollingForConnection() {
    final shouldUseRestFallback =
        _realtimeClient?.shouldUseRestFallback ?? true;

    if (_isAppActive && shouldUseRestFallback) {
      _startUnreadPolling();
      return;
    }

    _stopUnreadPolling();
  }

  void _startUnreadPolling() {
    if (!_isAppActive ||
        !(_realtimeClient?.shouldUseRestFallback ?? true) ||
        (_unreadPollingTimer?.isActive ?? false)) {
      return;
    }

    _unreadPollingTimer = Timer.periodic(
      _unreadPollingInterval,
      (_) {
        unawaited(
          _refreshCustomerUnreadCount(),
        );
      },
    );
  }

  void _stopUnreadPolling() {
    _unreadPollingTimer?.cancel();
    _unreadPollingTimer = null;
  }

  Future<void> _refreshCustomerUnreadCount() async {
    if (_unreadRequestInProgress) {
      return;
    }

    final repository = widget.customerRepository;
    final storeId =
        widget.storeSelectionController?.selectedStoreId;

    final requestSerial = ++_unreadRequestSerial;

    if (repository == null || storeId == null) {
      if (!mounted) {
        return;
      }

      if (_customerUnreadCount != 0) {
        setState(() {
          _customerUnreadCount = 0;
        });
      }

      return;
    }

    _unreadRequestInProgress = true;

    try {
      final unreadCount =
          await repository.countUnreadMessages(
        storeId,
      );

      if (!mounted ||
          requestSerial != _unreadRequestSerial ||
          widget.storeSelectionController?.selectedStoreId !=
              storeId) {
        return;
      }

      if (_customerUnreadCount == unreadCount) {
        return;
      }

      setState(() {
        _customerUnreadCount = unreadCount;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '고객 문의 읽지 않은 메시지 수를 '
        '불러오지 못했습니다: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      _unreadRequestInProgress = false;
    }
  }

  void _resetUnreadCount() {
    _unreadRequestSerial++;

    if (!mounted || _customerUnreadCount == 0) {
      return;
    }

    setState(() {
      _customerUnreadCount = 0;
    });
  }

  int _indexForLocation(String value) {
    final index = _locations.indexWhere(
      (candidate) => value.startsWith(candidate),
    );

    return index < 0 ? 0 : index;
  }

  Future<void> _signOut(
    BuildContext context,
  ) async {
    await widget.onSignOut();

    if (context.mounted) {
      context.go(
        SellerRoutes.signIn,
      );
    }
  }
}

class _CustomerNavigationIcon extends StatelessWidget {
  const _CustomerNavigationIcon({
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
      width: 36,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon),
          Positioned(
            top: -4,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 17,
                minHeight: 17,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
              ),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.surface,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
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

class _OperationalNotificationIcon extends StatelessWidget {
  const _OperationalNotificationIcon({required this.alertCount});

  final int alertCount;

  @override
  Widget build(BuildContext context) {
    if (alertCount <= 0) {
      return const Icon(Icons.notifications_none_rounded);
    }
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '확인할 운영 알림 $alertCount개',
      child: SizedBox(
        width: 32,
        height: 28,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_rounded),
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  alertCount > 99 ? '99+' : '$alertCount',
                  style: TextStyle(
                    color: colors.onError,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
