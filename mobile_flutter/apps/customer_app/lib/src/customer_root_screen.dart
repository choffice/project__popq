import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'routing/customer_router.dart';

class CustomerRootScreen extends StatelessWidget {
  const CustomerRootScreen({
    required this.location,
    required this.child,
    super.key,
  });

  static const _locations = [
    CustomerRoutes.home,
    CustomerRoutes.discover,
    CustomerRoutes.orders,
    CustomerRoutes.profile,
  ];
  static const _titles = ['POPQ', '스토어 찾기', '주문 내역', '마이 POPQ'];

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForLocation(location);
    return PopqAppScaffold(
      title: _titles[selectedIndex],
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => context.go(_locations[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: '홈',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_rounded),
          selectedIcon: Icon(Icons.manage_search_rounded),
          label: '탐색',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: '주문',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: '마이',
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
}
