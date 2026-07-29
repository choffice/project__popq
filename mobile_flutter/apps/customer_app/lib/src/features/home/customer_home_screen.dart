import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
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
            color: PopqPalette.forest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEARBY MOMENTS',
                style: TextStyle(
                  color: PopqPalette.lime,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: PopqSpacing.sm),
              Text(
                '지금 가까운 곳의\n좋은 경험을 찾아보세요.',
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: PopqSpacing.lg),
              FilledButton.icon(
                onPressed: () => context.go(CustomerRoutes.discover),
                style: FilledButton.styleFrom(
                  backgroundColor: PopqPalette.coral,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.near_me_rounded),
                label: const Text('내 주변 스토어 보기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: PopqSpacing.lg),
        Text('무엇을 도와드릴까요?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: PopqSpacing.md),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.go(CustomerRoutes.discover),
          child: const PopqFeatureCard(
            icon: Icons.search_rounded,
            title: '취향으로 탐색',
            description: '키워드와 태그로 원하는 스토어를 발견하세요.',
          ),
        ),
        const SizedBox(height: PopqSpacing.sm),
        const PopqFeatureCard(
          icon: Icons.favorite_border_rounded,
          title: '관심 스토어',
          description: '다시 찾고 싶은 곳의 새 소식을 모아보세요.',
          accent: Color(0xFFFFD2C9),
        ),
        const SizedBox(height: PopqSpacing.sm),
        const PopqFeatureCard(
          icon: Icons.receipt_long_rounded,
          title: '주문 이어보기',
          description: '진행 중인 주문과 지난 주문을 확인하세요.',
          accent: Color(0xFFD9D2FF),
        ),
      ],
    );
  }
}
