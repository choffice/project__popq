import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'store_discovery_repository.dart';

Future<void> showStoreHoursDialog(
  BuildContext context, {
  required CustomerStore store,
  String? description,
}) async {
  final schedule = store.resolvedSchedule;
  final title = switch (store.businessStatus) {
    'PRE_OPEN' => '아직 오픈 전이에요',
    _ when !store.orderAcceptingEnabled => '현재 주문 접수 중지',
    _ => '현재 영업시간이 아니에요',
  };
  final message = description ??
      (store.orderAcceptingEnabled
          ? '상품은 자유롭게 둘러보고 장바구니에 담을 수 있어요. '
              '결제는 영업시간에 진행해주세요.'
          : '상품은 자유롭게 둘러보고 장바구니에 담을 수 있어요. '
              '주문 접수가 재개되면 결제할 수 있습니다.');

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: PopqSpacing.md),
            Text(
              schedule.todayLabel(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: PopqSpacing.xs),
            ...schedule.summaryLines().map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(top: PopqSpacing.xs),
                    child: Text(line),
                  ),
                ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
