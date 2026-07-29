import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/home/seller_home_screen.dart';

class SellerRootScreen extends StatefulWidget {
  const SellerRootScreen({super.key});

  @override
  State<SellerRootScreen> createState() => _SellerRootScreenState();
}

class _SellerRootScreenState extends State<SellerRootScreen> {
  static const _titles = ['오늘의 운영', '주문', '상품', '내 스토어'];
  static const _pages = [
    SellerHomeScreen(),
    _SectionPlaceholder(
      icon: Icons.notifications_active_outlined,
      title: '신규 주문',
      description: '푸시 알림과 주문 상태 처리는 9.6에서 연결합니다.',
    ),
    _SectionPlaceholder(
      icon: Icons.inventory_2_outlined,
      title: '상품·품절',
      description: '판매 상태와 빠른 품절 처리는 9.6에서 연결합니다.',
    ),
    _SectionPlaceholder(
      icon: Icons.storefront_outlined,
      title: '내 스토어',
      description: '스토어 선택과 영업 상태 관리는 9.6에서 연결합니다.',
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PopqAppScaffold(
      title: _titles[_selectedIndex],
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
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
      body: IndexedStack(index: _selectedIndex, children: _pages),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PopqSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: PopqPalette.forest),
            const SizedBox(height: PopqSpacing.md),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: PopqSpacing.sm),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
