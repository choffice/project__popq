import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'routing/seller_router.dart';

class SellerRootScreen extends StatelessWidget {
  const SellerRootScreen({
    required this.location,
    required this.onSignOut,
    required this.child,
    super.key,
  });

  static const _locations = [
    SellerRoutes.dashboard,
    SellerRoutes.operations,
    SellerRoutes.orders,
    SellerRoutes.customers,
    SellerRoutes.sales,
  ];

  static const _titles = [
    '대시보드',
    '운영',
    '주문 관리',
    '고객',
    '매출',
  ];

  final String location;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForLocation(location);

    return PopqAppScaffold(
      title: _titles[selectedIndex],
      actions: [
        if (location != SellerRoutes.dashboard)
          IconButton(
            tooltip: '사업장 전환',
            onPressed: () {
              context.go(SellerRoutes.dashboard);
            },
            icon: const Icon(
              Icons.swap_horiz_rounded,
            ),
          ),
        IconButton(
          tooltip: '판매자 설정',
          onPressed: () {
            context.push(SellerRoutes.settings);
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
        context.go(_locations[index]);
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
      body: child,
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
    await onSignOut();

    if (context.mounted) {
      context.go(SellerRoutes.signIn);
    }
  }
}