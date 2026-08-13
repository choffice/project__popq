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
    'PRE_OPEN' => '현재 영업 준비 중이에요',
    _ when !store.orderAcceptingEnabled => '현재 주문 접수 중지',
    _ => '현재 주문할 수 없어요',
  };
  final message = description ??
      '상품은 자유롭게 둘러보고 장바구니에 담을 수 있어요. '
          '판매자가 영업을 시작하면 주문할 수 있습니다. '
          '표시된 영업시간은 방문을 위한 안내 정보입니다.';

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
