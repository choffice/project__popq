import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

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
    super.key,
  });

  final String location;
  final Future<void> Function() onSignOut;
  final Widget child;

  final SellerCustomerRepository? customerRepository;
  final SellerStoreSelectionController? storeSelectionController;

  @override
  State<SellerRootScreen> createState() {
    return _SellerRootScreenState();
  }
}

class _SellerRootScreenState extends State<SellerRootScreen> {
  static const List<String> _locations = [
    SellerRoutes.dashboard,
    SellerRoutes.operations,
    SellerRoutes.orders,
    SellerRoutes.customers,
    SellerRoutes.sales,
  ];

  static const List<String> _titles = [
    '대시보드',
    '운영',
    '주문 관리',
    '고객',
    '매출',
  ];

  static const Duration _exitConfirmDuration = Duration(
    seconds: 2,
  );

  DateTime? _lastBackPressedAt;

  int _customerUnreadCount = 0;
  int _unreadRequestSerial = 0;

  @override
  void initState() {
    super.initState();

    widget.storeSelectionController?.addListener(
      _handleStoreSelectionChanged,
    );

    unawaited(
      SystemNavigator.setFrameworkHandlesBack(true),
    );

    _scheduleUnreadRefresh();
  }

  @override
  void didUpdateWidget(
      covariant SellerRootScreen oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.location != widget.location) {
      _lastBackPressedAt = null;
    }

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

    // 채팅 상세 화면에서 목록으로 돌아왔을 때처럼
    // 경로 문자열이 같아도 읽지 않은 메시지 수를 다시 조회한다.
    _scheduleUnreadRefresh();
  }

  @override
  void dispose() {
    _unreadRequestSerial++;

    widget.storeSelectionController?.removeListener(
      _handleStoreSelectionChanged,
    );

    unawaited(
      SystemNavigator.setFrameworkHandlesBack(false),
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForLocation(
      widget.location,
    );

    return BackButtonListener(
      onBackButtonPressed: _handleRootBackButtonPressed,
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (
            bool didPop,
            Object? result,
            ) {
          if (didPop) {
            return;
          }

          _handleSystemBack();
        },
        child: PopqAppScaffold(
          title: _titles[selectedIndex],
          actions: [
            if (widget.location != SellerRoutes.dashboard)
              IconButton(
                tooltip: '사업장 전환',
                onPressed: () {
                  _lastBackPressedAt = null;

                  context.go(
                    SellerRoutes.dashboard,
                  );
                },
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                ),
              ),
            IconButton(
              tooltip: '판매자 설정',
              onPressed: () {
                _lastBackPressedAt = null;

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

            _lastBackPressedAt = null;

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
                Icons.query_stats_outlined,
              ),
              selectedIcon: Icon(
                Icons.query_stats_rounded,
              ),
              label: '매출',
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

    if (widget.location != SellerRoutes.dashboard) {
      _lastBackPressedAt = null;

      context.go(
        SellerRoutes.dashboard,
      );

      return;
    }

    final now = DateTime.now();
    final previousPressedAt = _lastBackPressedAt;

    final shouldExit =
        previousPressedAt != null &&
            now.difference(previousPressedAt) <=
                _exitConfirmDuration;

    if (shouldExit) {
      _lastBackPressedAt = null;

      unawaited(
        SystemNavigator.pop(),
      );

      return;
    }

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

  Future<void> _refreshCustomerUnreadCount() async {
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

    try {
      final unreadCount =
      await repository.countUnreadMessages(
        storeId,
      );

      if (!mounted ||
          requestSerial != _unreadRequestSerial) {
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
        '고객 문의 읽지 않은 메시지 수를 불러오지 못했습니다: '
            '$error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
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
    _lastBackPressedAt = null;

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