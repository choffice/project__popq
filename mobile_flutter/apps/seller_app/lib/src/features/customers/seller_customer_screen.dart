import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

class SellerCustomerScreen extends StatelessWidget {
  const SellerCustomerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PopqEmptyView(
      icon: Icons.forum_outlined,
      title: '도착한 고객 메시지가 없어요.',
      description: '고객 메시지가 도착하면 사업장별 대화 목록과 미확인 상태를 이곳에서 관리합니다.',
    );
  }
}
