import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../stores/seller_store_repository.dart';
import '../stores/seller_store_selection_controller.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({
    required this.repository,
    required this.selectionController,
    super.key,
  });

  final SellerStoreRepository repository;
  final SellerStoreSelectionController selectionController;

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  late Future<SellerStore> _store;

  @override
  void initState() {
    super.initState();
    _store = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SellerStore>(
      future: _store,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const PopqLoadingView(message: '운영 스토어를 확인하고 있어요.');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return PopqErrorView(
            message: '선택한 스토어를 불러오지 못했어요. 스토어를 다시 선택해 주세요.',
            onRetry: _reload,
          );
        }
        final store = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              PopqSpacing.md,
              PopqSpacing.sm,
              PopqSpacing.md,
              PopqSpacing.xl,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(PopqSpacing.lg),
                decoration: BoxDecoration(
                  color: PopqPalette.ink,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roleLabel(store.myRole).toUpperCase(),
                      style: const TextStyle(
                        color: PopqPalette.lime,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: PopqSpacing.xs),
                    Text(
                      store.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: PopqSpacing.md),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: PopqSpacing.sm),
                        Text(
                          _businessStatusLabel(store.businessStatus),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PopqSpacing.sm),
                    const Text(
                      '영업 상태 변경과 오늘의 매출은 9.6D에서 연결합니다.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PopqSpacing.lg),
              Text('빠른 운영', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: PopqSpacing.md),
              const PopqFeatureCard(
                icon: Icons.notifications_active_outlined,
                title: '신규 주문 확인',
                description: '주문 처리 기능은 9.6B에서 연결합니다.',
                accent: Color(0xFFFFD2C9),
              ),
              const SizedBox(height: PopqSpacing.sm),
              const PopqFeatureCard(
                icon: Icons.inventory_2_outlined,
                title: '빠른 품절 관리',
                description: '상품 판매 상태는 9.6C에서 연결합니다.',
              ),
              const SizedBox(height: PopqSpacing.sm),
              const PopqFeatureCard(
                icon: Icons.query_stats_rounded,
                title: '오늘의 매출',
                description: '매출 분석은 9.6D에서 연결합니다.',
                accent: Color(0xFFD9D2FF),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<SellerStore> _load() async {
    final selectedId = widget.selectionController.selectedStoreId;
    if (selectedId == null) {
      throw StateError('selected store is missing');
    }
    final stores = await widget.repository.findAll();
    return stores.firstWhere((store) => store.storeId == selectedId);
  }

  void _reload() {
    setState(() => _store = _load());
  }
}

String _roleLabel(String role) {
  return switch (role) {
    'OWNER' => 'Owner',
    'MANAGER' => 'Manager',
    'STAFF' => 'Staff',
    _ => role,
  };
}

String _businessStatusLabel(String status) {
  return switch (status) {
    'OPEN' => '영업 중',
    'CLOSED' => '영업 종료',
    'PRE_OPEN' => '영업 준비',
    _ => status,
  };
}
