import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_repository.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_screen.dart';

void main() {
  testWidgets('EVENT 선택 카드에 스토어명과 별도로 행사명과 짧은 기간을 표시한다', (tester) async {
    await _pumpCard(
      tester,
      CustomerStore(
        storeId: 1,
        storeType: 'EVENT_COMMERCE',
        name: '모모 로스터스 부스',
        eventName: '부산 커피 페스타',
        businessStatus: 'OPEN',
        tags: [],
        address: '부산광역시 부산진구',
        latitude: 35.157778,
        longitude: 129.059167,
        operationStartDate: DateTime(2026, 8, 14),
        operationEndDate: DateTime(2026, 8, 18),
      ),
    );

    expect(find.text('모모 로스터스 부스'), findsOneWidget);
    expect(find.byKey(const Key('selected-store-event-name')), findsOneWidget);
    expect(find.text('부산 커피 페스타'), findsOneWidget);
    expect(
      find.byKey(const Key('selected-store-event-period')),
      findsOneWidget,
    );
    expect(find.text('8.14 ~ 8.18'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LOCAL 선택 카드에는 행사명과 행사기간 영역을 표시하지 않는다', (tester) async {
    await _pumpCard(
      tester,
      CustomerStore(
        storeId: 2,
        storeType: 'LOCAL_STORE',
        name: '부산 동네 가게',
        businessStatus: 'OPEN',
        tags: [],
        address: '부산광역시 부산진구',
        latitude: 35.157778,
        longitude: 129.059167,
        operationStartDate: DateTime(2026, 8, 14),
      ),
    );

    expect(find.byKey(const Key('selected-store-event-name')), findsNothing);
    expect(find.byKey(const Key('selected-store-event-period')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(WidgetTester tester, CustomerStore store) async {
  tester.view.physicalSize = const Size(390, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: buildSelectedStoreCardForTest(store),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
