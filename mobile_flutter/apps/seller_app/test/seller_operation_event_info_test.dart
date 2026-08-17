import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_seller_app/src/features/announcements/seller_announcement_repository.dart';
import 'package:popq_seller_app/src/features/home/seller_analytics_repository.dart';
import 'package:popq_seller_app/src/features/operations/seller_operation_screen.dart';
import 'package:popq_seller_app/src/features/orders/seller_order_repository.dart';
import 'package:popq_seller_app/src/features/products/seller_product_repository.dart';
import 'package:popq_seller_app/src/features/reviews/seller_review_repository.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_repository.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_selection_controller.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_selection_store.dart';

void main() {
  testWidgets('LOCAL legacy 사업장은 행사명 없이 미설정 운영기간을 표시한다', (
    WidgetTester tester,
  ) async {
    await _pumpOperation(
      tester,
      const SellerStore(
        storeId: 1,
        storeType: 'LOCAL_STORE',
        name: '일반 매장',
        status: 'ACTIVE',
        businessStatus: 'PRE_OPEN',
        myRole: 'OWNER',
      ),
    );

    expect(find.byKey(const Key('operation-event-name')), findsNothing);
    expect(find.byKey(const Key('operation-period')), findsOneWidget);
    expect(find.text('미설정 ~ 종료일 없음'), findsOneWidget);
  });

  testWidgets('EVENT 사업장은 행사명과 운영기간을 표시한다', (WidgetTester tester) async {
    await _pumpOperation(
      tester,
      SellerStore(
        storeId: 2,
        storeType: 'EVENT_COMMERCE',
        name: '행사 부스',
        eventName: '부산 커피 페스타',
        operationStartDate: DateTime(2026, 8, 14),
        operationEndDate: DateTime(2026, 8, 18),
        status: 'ACTIVE',
        businessStatus: 'PRE_OPEN',
        myRole: 'OWNER',
      ),
    );

    expect(find.byKey(const Key('operation-event-name')), findsOneWidget);
    expect(find.text('부산 커피 페스타'), findsOneWidget);
    expect(find.text('2026.08.14 ~ 2026.08.18'), findsOneWidget);
  });

  testWidgets('전체 수정 복귀 후 repository 최신값으로 EVENT 표시를 갱신한다', (
    WidgetTester tester,
  ) async {
    final _OperationHarness harness = await _pumpOperation(
      tester,
      SellerStore(
        storeId: 3,
        storeType: 'EVENT_COMMERCE',
        name: '행사 부스',
        eventName: '변경 전 행사',
        operationStartDate: DateTime(2026, 8, 14),
        operationEndDate: DateTime(2026, 8, 18),
        status: 'ACTIVE',
        businessStatus: 'PRE_OPEN',
        myRole: 'OWNER',
      ),
    );

    final Finder editButton = find.byKey(const Key('edit-store'));
    await tester.scrollUntilVisible(
      editButton,
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    final SellerStore changedEvent = await harness.repository.update(
      3,
      storeType: 'EVENT_COMMERCE',
      name: '행사 부스',
      eventName: '변경된 행사',
      operationStartDate: DateTime(2026, 8, 15),
      operationEndDate: DateTime(2026, 8, 19),
    );
    Navigator.of(
      tester.element(find.text('사업장 정보 수정')),
    ).pop<SellerStore>(changedEvent);
    await tester.pumpAndSettle();

    expect(find.text('변경된 행사'), findsOneWidget);
    expect(find.text('2026.08.15 ~ 2026.08.19'), findsOneWidget);

    await tester.scrollUntilVisible(
      editButton,
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    final SellerStore changedLocal = await harness.repository.update(
      3,
      storeType: 'LOCAL_STORE',
      name: '행사 부스',
      eventName: null,
      operationStartDate: null,
      operationEndDate: null,
    );
    Navigator.of(
      tester.element(find.text('사업장 정보 수정')),
    ).pop<SellerStore>(changedLocal);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('operation-event-name')), findsNothing);
    expect(find.text('변경된 행사'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}

Future<_OperationHarness> _pumpOperation(
  WidgetTester tester,
  SellerStore store,
) async {
  final MemorySellerStoreRepository repository = MemorySellerStoreRepository(
    stores: <SellerStore>[store],
  );
  final SellerStoreSelectionController selectionController =
      SellerStoreSelectionController(MemorySellerStoreSelectionStore());
  await selectionController.select(store.storeId);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SellerOperationScreen(
          storeRepository: repository,
          announcementRepository: MemorySellerAnnouncementRepository(),
          productRepository: MemorySellerProductRepository(),
          analyticsRepository: MemorySellerAnalyticsRepository(),
          reviewRepository: MemorySellerReviewRepository(),
          orderRepository: MemorySellerOrderRepository(),
          selectionController: selectionController,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _OperationHarness(repository: repository);
}

class _OperationHarness {
  const _OperationHarness({required this.repository});

  final MemorySellerStoreRepository repository;
}
