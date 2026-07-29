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
    SellerRoutes.home,
    SellerRoutes.orders,
    SellerRoutes.products,
    SellerRoutes.stores,
  ];
  static const _titles = ['오늘의 운영', '주문', '상품', '내 스토어'];

  final String location;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForLocation(location);
    return PopqAppScaffold(
      title: _titles[selectedIndex],
      actions: [
        if (location != SellerRoutes.stores)
          IconButton(
            tooltip: '스토어 전환',
            onPressed: () => context.go(SellerRoutes.stores),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        IconButton(
          tooltip: '로그아웃',
          onPressed: () => _signOut(context),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => context.go(_locations[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard_rounded),
          label: '운영',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications_rounded),
          label: '주문',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded),
          label: '상품',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront_rounded),
          label: '스토어',
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

  Future<void> _signOut(BuildContext context) async {
    await onSignOut();
    if (context.mounted) context.go(SellerRoutes.signIn);
  }
}
