import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_customer_app/src/features/announcements/public_announcement_repository.dart';
import 'package:popq_customer_app/src/features/catalog/catalog_repository.dart';
import 'package:popq_customer_app/src/features/discovery/store_detail_screen.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_repository.dart';
import 'package:popq_customer_app/src/features/profile/customer_engagement_repository.dart';

void main() {
  testWidgets('EVENT 상세에 스토어명과 별도로 행사명과 행사기간을 표시한다', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      CustomerStore(
        storeId: 1,
        storeType: 'EVENT_COMMERCE',
        eventName: '부산 바다 푸드 페스타',
        name: '달빛 푸드트럭',
        businessStatus: 'PRE_OPEN',
        operationStartDate: DateTime(2026, 8, 14),
        operationEndDate: DateTime(2026, 8, 18),
        tags: const <String>[],
      ),
    );

    expect(find.text('달빛 푸드트럭'), findsWidgets);
    expect(find.byKey(const Key('store-detail-event-name')), findsOneWidget);
    expect(find.text('부산 바다 푸드 페스타'), findsOneWidget);
    expect(find.text('행사 기간'), findsOneWidget);
    expect(find.text('2026.08.14 ~ 2026.08.18'), findsOneWidget);
  });

  testWidgets('legacy EVENT의 eventName이 null이어도 상세가 렌더링된다', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      CustomerStore(
        storeId: 2,
        storeType: 'EVENT_COMMERCE',
        name: '행사 부스',
        businessStatus: 'PRE_OPEN',
        operationStartDate: DateTime(2026, 8, 14),
        operationEndDate: DateTime(2026, 8, 18),
        tags: const <String>[],
      ),
    );

    expect(find.byKey(const Key('store-detail-event-name')), findsNothing);
    expect(find.text('행사 기간'), findsOneWidget);
  });

  testWidgets('LOCAL 상세에는 행사명 영역을 표시하지 않고 기존 오픈일을 유지한다', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      CustomerStore(
        storeId: 3,
        storeType: 'LOCAL_STORE',
        name: '동네 카페',
        businessStatus: 'OPEN',
        operationStartDate: DateTime(2026, 8, 14),
        tags: const <String>[],
      ),
    );

    expect(find.byKey(const Key('store-detail-event-name')), findsNothing);
    expect(find.text('오픈일'), findsOneWidget);
    expect(find.text('2026.08.14 영업 시작'), findsOneWidget);
  });
}

Future<void> _pumpDetail(WidgetTester tester, CustomerStore store) async {
  final SessionController sessionController = SessionController(
    sessionStore: MemorySessionStore(),
  );
  await sessionController.restore();

  await tester.pumpWidget(
    MaterialApp(
      home: StoreDetailScreen(
        storeId: store.storeId,
        repository: MemoryStoreDiscoveryRepository(
          stores: <CustomerStore>[store],
        ),
        engagementRepository: MemoryCustomerEngagementRepository(),
        sessionController: sessionController,
        catalogRepository: MemoryCatalogRepository(
          products: const <CatalogProduct>[],
        ),
        announcementRepository: const MemoryPublicAnnouncementRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
