import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/common/theme_mode_toggle.dart';
import 'features/customers/seller_customer_repository.dart';
import 'features/stores/seller_store_selection_controller.dart';
import 'routing/seller_router.dart';

class SellerRootScreen extends StatefulWidget {
  const SellerRootScreen({
    required this.location,
    required this.onSignOut,
    required this.child,
    this.customerRepository,
    this.storeSelectionController,
    this.themeController,
    super.key,
  });

  final String location;
  final Future<void> Function() onSignOut;
  final Widget child;

  final SellerCustomerRepository? customerRepository;
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

  int _customerUnreadCount = 0;
  int _unreadRequestSerial = 0;

  Timer? _unreadPollingTimer;

  bool _unreadRequestInProgress = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    widget.storeSelectionController?.addListener(
      _handleStoreSelectionChanged,
    );

    _scheduleUnreadRefresh();
    _startUnreadPolling();
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
    }

    if (oldWidget.customerRepository !=
        widget.customerRepository) {
      _resetUnreadCount();
    }

    /*
     * 채팅 상세에서 목록으로 돌아왔을 때처럼
     * 경로 문자열이 같더라도 읽지 않은 수를 다시 확인합니다.
     */
    _scheduleUnreadRefresh();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _startUnreadPolling();

      unawaited(
        _refreshCustomerUnreadCount(),
      );

      return;
    }

    /*
     * 앱이 백그라운드로 이동하면
     * 불필요한 API 요청을 중지합니다.
     */
    _stopUnreadPolling();
  }

  @override
  void dispose() {
    _unreadRequestSerial++;

    _stopUnreadPolling();

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
          tooltip: '판매자 설정',
          onPressed: () {
            context.push(
              SellerRoutes.settings,
            );
          },
          icon: const Icon(
            Icons.settings_rounded,
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

    unawaited(
      _refreshCustomerUnreadCount(),
    );
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

  void _startUnreadPolling() {
    if (_unreadPollingTimer?.isActive ?? false) {
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
      /*
       * 자동 조회가 한 번 실패해도 기존 배지는 유지합니다.
       * 다음 폴링 주기에 다시 조회합니다.
       */
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