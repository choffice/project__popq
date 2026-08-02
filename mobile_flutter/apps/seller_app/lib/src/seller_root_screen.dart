import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'routing/seller_router.dart';

class SellerRootScreen extends StatefulWidget {
  const SellerRootScreen({
    required this.location,
    required this.onSignOut,
    required this.child,
    super.key,
  });

  final String location;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  State<SellerRootScreen> createState() =>
      _SellerRootScreenState();
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
      covariant SellerRootScreen oldWidget,
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
            final nextLocation = _locations[index];

            if (nextLocation == widget.location) {
              return;
            }

            _lastBackPressedAt = null;

            context.go(nextLocation);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons.business_outlined,
              ),
              selectedIcon: Icon(
                Icons.business_rounded,
              ),
              label: '대시보드',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.tune_outlined,
              ),
              selectedIcon: Icon(
                Icons.tune_rounded,
              ),
              label: '운영',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.notifications_none_rounded,
              ),
              selectedIcon: Icon(
                Icons.notifications_rounded,
              ),
              label: '주문',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.forum_outlined,
              ),
              selectedIcon: Icon(
                Icons.forum_rounded,
              ),
              label: '고객',
            ),
            NavigationDestination(
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