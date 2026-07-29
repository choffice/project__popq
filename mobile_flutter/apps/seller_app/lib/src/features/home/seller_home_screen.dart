import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

class SellerHomeScreen extends StatelessWidget {
  const SellerHomeScreen({super.key});

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
            color: PopqPalette.ink,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEONGSU LOUNGE',
                          style: TextStyle(
                            color: PopqPalette.lime,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: PopqSpacing.xs),
                        Text(
                          '운영 준비 중',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(value: false, onChanged: (_) {}),
                ],
              ),
              const SizedBox(height: PopqSpacing.lg),
              const Text(
                '스토어 연결 후 주문과 영업 상태가 여기에 표시됩니다.',
                style: TextStyle(color: Colors.white70, height: 1.5),
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
          description: '접수 대기 주문을 놓치지 않고 처리하세요.',
          accent: Color(0xFFFFD2C9),
        ),
        const SizedBox(height: PopqSpacing.sm),
        const PopqFeatureCard(
          icon: Icons.inventory_2_outlined,
          title: '빠른 품절 관리',
          description: '판매할 수 없는 상품을 즉시 품절 처리하세요.',
        ),
        const SizedBox(height: PopqSpacing.sm),
        const PopqFeatureCard(
          icon: Icons.query_stats_rounded,
          title: '오늘의 매출',
          description: '완료 주문과 기본 매출 흐름을 확인하세요.',
          accent: Color(0xFFD9D2FF),
        ),
      ],
    );
  }
}
