import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_seller_app/src/features/stores/seller_business_schedule.dart';

void main() {
  testWidgets('공휴일 데이터 사용 가능 여부에 맞는 안내를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpEditor(tester, available: true);
    expect(find.text('대한민국 공휴일에는 자동으로 휴무 처리됩니다.'), findsOneWidget);

    await _pumpEditor(tester, available: false);
    expect(find.text('정책은 저장되지만 현재 자동 공휴일 판정 데이터는 없습니다.'), findsOneWidget);
  });
}

Future<void> _pumpEditor(WidgetTester tester, {required bool available}) async {
  final SellerBusinessSchedule schedule = SellerBusinessSchedule(
    businessHours: SellerBusinessSchedule.standard().businessHours,
    publicHolidayAutoCalculationAvailable: available,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SellerBusinessScheduleEditor(
            initialSchedule: schedule,
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
