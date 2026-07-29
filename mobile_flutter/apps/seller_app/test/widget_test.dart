import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_seller_app/src/features/auth/seller_identity_repository.dart';
import 'package:popq_seller_app/src/features/orders/seller_order_repository.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_repository.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_selection_store.dart';
import 'package:popq_seller_app/src/seller_app.dart';

void main() {
  testWidgets('signed-out seller sees only the seller login flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: MemorySessionStore(),
        storeSelectionStore: MemorySellerStoreSelectionStore(),
        storeRepository: MemorySellerStoreRepository(),
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: MemorySellerOrderRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POPQ SELLER'), findsOneWidget);
    expect(find.text('개발용 판매자로 로그인'), findsOneWidget);
    expect(find.textContaining('고객 앱과 다른 SELLER 계정'), findsOneWidget);
  });

  testWidgets('restored seller session opens the selected store workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: _validSessionStore(),
        storeSelectionStore: MemorySellerStoreSelectionStore(1),
        storeRepository: MemorySellerStoreRepository(),
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: MemorySellerOrderRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('성수 커피 연구소'), findsOneWidget);
    expect(find.text('영업 준비'), findsOneWidget);

    await tester.tap(find.text('주문'));
    await tester.pumpAndSettle();
    expect(find.text('아직 주문이 없어요.'), findsOneWidget);
  });

  testWidgets('customer identity is rejected and account state is cleared', (
    tester,
  ) async {
    final sessionStore = _validSessionStore();
    final selectionStore = MemorySellerStoreSelectionStore(1);
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: sessionStore,
        storeSelectionStore: selectionStore,
        storeRepository: MemorySellerStoreRepository(),
        identityRepository: const MemorySellerIdentityRepository(
          identity: SellerIdentity(
            userId: 9,
            email: 'customer@popq.test',
            name: 'POPQ 고객',
            role: 'CUSTOMER',
          ),
        ),
        orderRepository: MemorySellerOrderRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('일반 고객 계정은 판매자 앱에서 사용할 수 없습니다'), findsOneWidget);
    expect(await sessionStore.read(), isNull);
    expect(await selectionStore.read(), isNull);
  });

  testWidgets('seller selects an owned store and logout clears the selection', (
    tester,
  ) async {
    final sessionStore = _validSessionStore();
    final selectionStore = MemorySellerStoreSelectionStore();
    final repository = MemorySellerStoreRepository(
      stores: const [
        SellerStore(
          storeId: 11,
          storeType: 'LOCAL_STORE',
          name: '첫 번째 스토어',
          status: 'ACTIVE',
          businessStatus: 'OPEN',
          myRole: 'OWNER',
        ),
        SellerStore(
          storeId: 22,
          storeType: 'EVENT_COMMERCE',
          name: '두 번째 팝업',
          status: 'ACTIVE',
          businessStatus: 'PRE_OPEN',
          myRole: 'MANAGER',
        ),
      ],
    );
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: sessionStore,
        storeSelectionStore: selectionStore,
        storeRepository: repository,
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: MemorySellerOrderRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('운영할 스토어를 선택하세요.'), findsOneWidget);
    await tester.tap(find.text('두 번째 팝업'));
    await tester.pumpAndSettle();

    expect(find.text('두 번째 팝업'), findsOneWidget);
    expect(await selectionStore.read(), 22);

    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('POPQ SELLER'), findsOneWidget);
    expect(await sessionStore.read(), isNull);
    expect(await selectionStore.read(), isNull);
  });

  testWidgets(
    'selected store sees only its orders and completes the valid lifecycle',
    (tester) async {
      final orderRepository = MemorySellerOrderRepository(
        orders: [
          _order(
            orderPublicId: 'store-one-order',
            storeId: 1,
            storeName: '성수 커피 연구소',
          ),
          _order(
            orderPublicId: 'store-two-order',
            storeId: 2,
            storeName: '다른 판매자 스토어',
          ),
        ],
      );
      await tester.pumpWidget(
        PopqSellerApp(
          environment: const AppEnvironment.local(),
          sessionStore: _validSessionStore(),
          storeSelectionStore: MemorySellerStoreSelectionStore(1),
          storeRepository: MemorySellerStoreRepository(),
          identityRepository: const MemorySellerIdentityRepository(),
          orderRepository: orderRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('주문'));
      await tester.pumpAndSettle();

      expect(find.textContaining('store-one-order'), findsOneWidget);
      expect(find.textContaining('store-two-order'), findsNothing);

      await tester.tap(find.textContaining('store-one-order'));
      await tester.pumpAndSettle();
      expect(find.text('접수 대기'), findsOneWidget);

      await tester.tap(find.byKey(const Key('accept-order')));
      await tester.pumpAndSettle();
      expect(find.text('접수 완료'), findsAtLeastNWidgets(1));

      await tester.tap(find.byKey(const Key('prepare-order')));
      await tester.pumpAndSettle();
      expect(find.text('준비 중'), findsAtLeastNWidgets(1));

      await tester.tap(find.byKey(const Key('ready-order')));
      await tester.pumpAndSettle();
      expect(find.text('준비 완료'), findsAtLeastNWidgets(1));

      await tester.tap(find.byKey(const Key('complete-order')));
      await tester.pumpAndSettle();
      expect(find.text('주문 완료'), findsAtLeastNWidgets(1));
      expect(find.byKey(const Key('complete-order')), findsNothing);

      final completed = await orderRepository.findOne(1, 'store-one-order');
      expect(completed.status, 'COMPLETED');
      expect(completed.version, 5);
    },
  );

  test('repository denies an order outside the selected store', () async {
    final repository = MemorySellerOrderRepository(
      orders: [
        _order(
          orderPublicId: 'other-store-order',
          storeId: 2,
          storeName: '다른 판매자 스토어',
        ),
      ],
    );

    await expectLater(
      repository.findOne(1, 'other-store-order'),
      throwsStateError,
    );
  });
}

MemorySessionStore _validSessionStore() {
  return MemorySessionStore(
    AuthSession(
      accessToken: 'seller-access',
      refreshToken: 'seller-refresh',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
  );
}

SellerOrder _order({
  required String orderPublicId,
  required int storeId,
  required String storeName,
}) {
  return SellerOrder(
    orderPublicId: orderPublicId,
    storeId: storeId,
    storeName: storeName,
    orderType: 'TAKEOUT',
    status: 'PLACED',
    subtotalAmount: 6500,
    discountAmount: 0,
    taxAmount: 0,
    serviceFeeAmount: 0,
    totalAmount: 6500,
    version: 1,
    items: const [
      SellerOrderItem(
        productName: '아메리카노',
        quantity: 1,
        unitPrice: 6500,
        itemTotalPrice: 6500,
        options: [],
      ),
    ],
  );
}
