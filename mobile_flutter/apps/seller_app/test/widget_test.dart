import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_seller_app/src/features/announcements/seller_announcement_repository.dart';
import 'package:popq_seller_app/src/features/auth/seller_auth_repository.dart';
import 'package:popq_seller_app/src/features/auth/seller_identity_repository.dart';
import 'package:popq_seller_app/src/features/home/seller_analytics_repository.dart';
import 'package:popq_seller_app/src/features/orders/seller_order_repository.dart';
import 'package:popq_seller_app/src/features/products/seller_product_repository.dart';
import 'package:popq_seller_app/src/features/products/seller_product_list_screen.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_repository.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_selection_controller.dart';
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
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POPQ SELLER'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('개발용 판매자로 로그인'), findsOneWidget);
    expect(find.textContaining('고객 앱과 다른 SELLER 계정'), findsOneWidget);
  });

  testWidgets('seller signs in with email and password', (tester) async {
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: MemorySessionStore(),
        storeSelectionStore: MemorySellerStoreSelectionStore(),
        storeRepository: MemorySellerStoreRepository(stores: const []),
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: MemorySellerOrderRepository(),
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
        authRepository: MemorySellerAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sign-in-email')),
      'seller@popq.test',
    );
    await tester.enterText(
      find.byKey(const Key('sign-in-password')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('sign-in-submit')));
    await tester.pumpAndSettle();

    expect(find.text('사업장 대시보드'), findsOneWidget);
  });

  testWidgets('seller signs up and returns to sign-in without auto-login', (
    tester,
  ) async {
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: MemorySessionStore(),
        storeSelectionStore: MemorySellerStoreSelectionStore(),
        storeRepository: MemorySellerStoreRepository(stores: const []),
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: MemorySellerOrderRepository(),
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
        authRepository: MemorySellerAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('go-to-sign-up')));
    await tester.pumpAndSettle();

    expect(find.text('판매자 회원가입'), findsAtLeastNWidgets(1));
    await tester.enterText(
      find.byKey(const Key('sign-up-email')),
      'new-seller@popq.test',
    );
    await tester.enterText(
      find.byKey(const Key('sign-up-name')),
      '신규 판매자',
    );
    await tester.enterText(
      find.byKey(const Key('sign-up-phone')),
      '010-1234-5678',
    );
    await tester.enterText(
      find.byKey(const Key('sign-up-password')),
      'password1',
    );
    await tester.enterText(
      find.byKey(const Key('sign-up-password-confirm')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('sign-up-submit')));
    await tester.pumpAndSettle();

    expect(find.text('회원가입이 완료되었습니다. 로그인해 주세요.'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-submit')), findsOneWidget);
  });

  testWidgets('seller finds their id with name and phone', (tester) async {
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: MemorySessionStore(),
        storeSelectionStore: MemorySellerStoreSelectionStore(),
        storeRepository: MemorySellerStoreRepository(stores: const []),
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: MemorySellerOrderRepository(),
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
        authRepository: MemorySellerAuthRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('go-to-find-id')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('find-id-name')), '홍길동');
    await tester.enterText(
      find.byKey(const Key('find-id-phone')),
      '010-1234-5678',
    );
    await tester.tap(find.byKey(const Key('find-id-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('se***@popq.test'), findsOneWidget);
  });

  testWidgets(
    'seller resets password via find-password flow',
    (tester) async {
      await tester.pumpWidget(
        PopqSellerApp(
          environment: const AppEnvironment.local(),
          sessionStore: MemorySessionStore(),
          storeSelectionStore: MemorySellerStoreSelectionStore(),
          storeRepository: MemorySellerStoreRepository(stores: const []),
          identityRepository: const MemorySellerIdentityRepository(),
          orderRepository: MemorySellerOrderRepository(),
          productRepository: MemorySellerProductRepository(),
          analyticsRepository: MemorySellerAnalyticsRepository(),
          authRepository: MemorySellerAuthRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('go-to-find-password')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('find-password-email')),
        'seller@popq.test',
      );
      await tester.enterText(
        find.byKey(const Key('find-password-phone')),
        '010-1234-5678',
      );
      await tester.tap(find.byKey(const Key('find-password-verify')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('find-password-new')),
        'newpassword1',
      );
      await tester.enterText(
        find.byKey(const Key('find-password-new-confirm')),
        'newpassword1',
      );
      await tester.tap(find.byKey(const Key('find-password-submit')));
      await tester.pumpAndSettle();

      expect(find.text('비밀번호가 변경되었습니다. 로그인해 주세요.'), findsOneWidget);
      expect(find.byKey(const Key('sign-in-submit')), findsOneWidget);
    },
  );

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
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('성수 커피 연구소'), findsOneWidget);
    expect(find.textContaining('영업 준비'), findsAtLeastNWidgets(1));

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
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
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
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('사업장 대시보드'), findsOneWidget);
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
          productRepository: MemorySellerProductRepository(),
          analyticsRepository: MemorySellerAnalyticsRepository(),
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

      final refundButton = find.byKey(const Key('refund-order'));
      await tester.drag(
        find.byKey(const Key('order-detail-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.text('결제 완료'), findsOneWidget);
      await tester.tap(refundButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('refund-reason')),
        '고객 요청 전액 환불',
      );
      await tester.tap(find.byKey(const Key('confirm-refund')));
      await tester.pumpAndSettle();

      expect(find.text('환불 완료'), findsAtLeastNWidgets(1));
      expect(find.text('고객 요청 전액 환불'), findsOneWidget);
      final payment = await orderRepository.findPayment(1, 'store-one-order');
      expect(payment.paymentStatus, 'REFUNDED');
      expect(payment.refundableAmount, 0);

      final completed = await orderRepository.findOne(1, 'store-one-order');
      expect(completed.status, 'COMPLETED');
      expect(completed.version, 5);
    },
  );

  testWidgets('staff can view payment but cannot request a refund', (
    tester,
  ) async {
    final orderRepository = MemorySellerOrderRepository(
      orders: [
        _order(
          orderPublicId: 'staff-completed-order',
          storeId: 1,
          storeName: '직원 운영 매장',
          status: 'COMPLETED',
          version: 5,
        ),
      ],
    );
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: _validSessionStore(),
        storeSelectionStore: MemorySellerStoreSelectionStore(1),
        storeRepository: MemorySellerStoreRepository(
          stores: const [
            SellerStore(
              storeId: 1,
              storeType: 'LOCAL_STORE',
              name: '직원 운영 매장',
              status: 'ACTIVE',
              businessStatus: 'OPEN',
              myRole: 'STAFF',
            ),
          ],
        ),
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: orderRepository,
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('주문'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('staff-completed-order'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('order-detail-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('결제 완료'), findsOneWidget);
    expect(find.byKey(const Key('refund-order')), findsNothing);
    expect(
      find.textContaining('OWNER 또는 MANAGER만'),
      findsOneWidget,
    );
  });

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

  testWidgets(
    'selected store manages sold-out and channel availability in isolation',
    (tester) async {
      final productRepository = MemorySellerProductRepository(
        products: [
          _product(productId: 101, storeId: 1, name: '성수 아메리카노'),
          _product(productId: 202, storeId: 2, name: '다른 스토어 라떼'),
        ],
      );
      await tester.pumpWidget(
        PopqSellerApp(
          environment: const AppEnvironment.local(),
          sessionStore: _validSessionStore(),
          storeSelectionStore: MemorySellerStoreSelectionStore(1),
          storeRepository: MemorySellerStoreRepository(),
          identityRepository: const MemorySellerIdentityRepository(),
          orderRepository: MemorySellerOrderRepository(),
          productRepository: productRepository,
          analyticsRepository: MemorySellerAnalyticsRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('운영'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('메뉴 관리'));
      await tester.pumpAndSettle();

      expect(find.text('성수 아메리카노'), findsOneWidget);
      expect(find.text('다른 스토어 라떼'), findsNothing);

      final soldOutSwitch = find.byKey(const Key('sold-out-101'));
      final soldOutControl = find.descendant(
        of: soldOutSwitch,
        matching: find.byType(Switch),
      );
      tester.widget<Switch>(soldOutControl).onChanged!(true);
      await tester.pumpAndSettle();

      var updated = (await productRepository.findAll(1)).single;
      expect(updated.soldOut, isTrue);
      expect(updated.availableForCustomerApp, isFalse);
      expect(updated.availableForQr, isFalse);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final customerSwitch = find.byKey(const Key('customer-app-101'));
      await tester.ensureVisible(customerSwitch);
      final customerControl = find.descendant(
        of: customerSwitch,
        matching: find.byType(Switch),
      );
      tester.widget<Switch>(customerControl).onChanged!(false);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final qrSwitch = find.byKey(const Key('qr-web-101'));
      await tester.ensureVisible(qrSwitch);
      final qrControl = find.descendant(
        of: qrSwitch,
        matching: find.byType(Switch),
      );
      tester.widget<Switch>(qrControl).onChanged!(false);
      await tester.pumpAndSettle();

      updated = (await productRepository.findAll(1)).single;
      expect(updated.customerAppEnabled, isFalse);
      expect(updated.qrWebEnabled, isFalse);
      expect(updated.soldOut, isTrue);
    },
  );

  test('repository denies a product outside the selected store', () async {
    final repository = MemorySellerProductRepository(
      products: [_product(productId: 7, storeId: 2, name: '타 스토어 상품')],
    );
    final foreignProduct = (await repository.findAll(2)).single;

    await expectLater(
      repository.updateAvailability(1, foreignProduct, soldOut: true),
      throwsStateError,
    );
    await expectLater(
      repository.replaceOptions(1, foreignProduct, const []),
      throwsStateError,
    );
  });

  testWidgets('seller creates a category and edits a menu', (tester) async {
    final repository = MemorySellerProductRepository();
    final selectionController = SellerStoreSelectionController(
      MemorySellerStoreSelectionStore(1),
    );
    await selectionController.restore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellerProductListScreen(
            repository: repository,
            selectionController: selectionController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name')),
      '시즌 메뉴',
    );
    await tester.enterText(find.byKey(const Key('category-order')), '1');
    await tester.tap(find.byKey(const Key('save-category')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-product')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('product-name')),
      '딸기 라떼',
    );
    await tester.enterText(find.byKey(const Key('product-price')), '6500');
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();

    expect(find.text('딸기 라떼'), findsOneWidget);
    var saved = (await repository.findAll(1)).single;
    expect(saved.basePrice, 6500);

    final edit = find.byKey(Key('edit-product-${saved.productId}'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('product-name')),
      '딸기 크림 라떼',
    );
    await tester.enterText(find.byKey(const Key('product-price')), '7000');
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();

    saved = (await repository.findAll(1)).single;
    expect(saved.name, '딸기 크림 라떼');
    expect(saved.basePrice, 7000);

    final optionEdit = find.byKey(Key('edit-options-${saved.productId}'));
    await tester.ensureVisible(optionEdit);
    await tester.tap(optionEdit);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('option-group-name-0')),
      '우유 선택',
    );
    await tester.enterText(
      find.byKey(const Key('option-name-0-0')),
      '오트 밀크',
    );
    await tester.enterText(
      find.byKey(const Key('option-price-0-0')),
      '800',
    );
    await tester.tap(find.byKey(const Key('save-options')));
    await tester.pumpAndSettle();

    final detail = await repository.findOne(1, saved);
    expect(detail.optionGroups.single.name, '우유 선택');
    expect(detail.optionGroups.single.options.single.additionalPrice, 800);
  });

  testWidgets(
    'operations dashboard uses the selected store and changes business status',
    (tester) async {
      final storeRepository = MemorySellerStoreRepository();
      final analyticsRepository = MemorySellerAnalyticsRepository(
        summaries: {
          1: const SellerSalesSummary(
            storeId: 1,
            from: '2026-07-29',
            to: '2026-07-29',
            netSales: 12000,
            completedOrderCount: 2,
            averageOrderAmount: 6000,
            dineInSales: 4500,
            takeoutSales: 7500,
            topProducts: [
              SellerTopProduct(name: '아메리카노', quantity: 2, sales: 9000),
            ],
          ),
          2: const SellerSalesSummary(
            storeId: 2,
            from: '2026-07-29',
            to: '2026-07-29',
            netSales: 999999,
            completedOrderCount: 99,
            averageOrderAmount: 10101,
            dineInSales: 999999,
            takeoutSales: 0,
            topProducts: [],
          ),
        },
      );
      await tester.pumpWidget(
        PopqSellerApp(
          environment: const AppEnvironment.local(),
          sessionStore: _validSessionStore(),
          storeSelectionStore: MemorySellerStoreSelectionStore(1),
          storeRepository: storeRepository,
          identityRepository: const MemorySellerIdentityRepository(),
          orderRepository: MemorySellerOrderRepository(),
          productRepository: MemorySellerProductRepository(),
          analyticsRepository: analyticsRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('매출'));
      await tester.pumpAndSettle();

      expect(find.text('12,000원'), findsAtLeastNWidgets(1));
      expect(find.text('2건'), findsOneWidget);
      expect(find.text('999,999원'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('아메리카노'), findsOneWidget);

      await tester.tap(find.text('운영'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('영업 중'));
      await tester.pumpAndSettle();

      final updatedStore = (await storeRepository.findAll()).single;
      expect(updatedStore.businessStatus, 'OPEN');
      expect(find.text('영업 중'), findsAtLeastNWidgets(1));

      await tester.drag(
        find.byType(ListView).last,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      final editButton = find.byKey(const Key('edit-store'));
      await tester.ensureVisible(editButton);
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('edit-store-name')),
        '성수 리뉴얼 사업장',
      );
      await tester.enterText(
        find.byKey(const Key('edit-store-address')),
        '서울 성동구 연무장길 1',
      );
      await tester.enterText(
        find.byKey(const Key('edit-store-tags')),
        'Coffee, Dessert, coffee',
      );
      await tester.tap(find.byKey(const Key('submit-store-edit')));
      await tester.pumpAndSettle();

      final editedStore = (await storeRepository.findAll()).single;
      expect(editedStore.name, '성수 리뉴얼 사업장');
      expect(editedStore.address, '서울 성동구 연무장길 1');
      expect(editedStore.tags, ['coffee', 'dessert']);
      expect(find.text('성수 리뉴얼 사업장'), findsOneWidget);
    },
  );

  testWidgets('owner creates edits and publishes a store announcement', (
    tester,
  ) async {
    final announcementRepository = MemorySellerAnnouncementRepository();
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: _validSessionStore(),
        storeSelectionStore: MemorySellerStoreSelectionStore(1),
        storeRepository: MemorySellerStoreRepository(),
        announcementRepository: announcementRepository,
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: MemorySellerOrderRepository(),
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('운영'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공지사항'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-announcement')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('announcement-title')),
      '여름 운영시간',
    );
    await tester.enterText(
      find.byKey(const Key('announcement-content')),
      '주말에는 오후 6시에 마감합니다.',
    );
    await tester.tap(find.byKey(const Key('save-announcement')));
    await tester.pumpAndSettle();

    expect(find.text('작성 중'), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-announcement-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('announcement-title')),
      '여름 운영시간 변경',
    );
    await tester.tap(find.byKey(const Key('save-announcement')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-announcement-1')));
    await tester.pumpAndSettle();

    final saved = (await announcementRepository.findAll(1)).single;
    expect(saved.title, '여름 운영시간 변경');
    expect(saved.status, 'PUBLISHED');
    expect(find.text('게시 중'), findsOneWidget);
  });

  test('repository denies an announcement outside the selected store', () async {
    final now = DateTime.now().toUtc();
    final foreign = SellerAnnouncement(
      announcementId: 7,
      storeId: 2,
      title: '다른 사업장 공지',
      content: '격리 대상',
      status: 'DRAFT',
      createdAt: now,
      updatedAt: now,
    );
    final repository = MemorySellerAnnouncementRepository(
      announcements: [foreign],
    );

    await expectLater(
      repository.update(
        1,
        foreign,
        title: '침범',
        content: '허용되지 않음',
      ),
      throwsStateError,
    );
  });

  test('staff cannot update business profile', () async {
    final repository = MemorySellerStoreRepository(
      stores: const [
        SellerStore(
          storeId: 1,
          storeType: 'LOCAL_STORE',
          name: '스태프 사업장',
          status: 'ACTIVE',
          businessStatus: 'OPEN',
          myRole: 'STAFF',
        ),
      ],
    );

    await expectLater(repository.update(1, name: '권한 없는 수정'), throwsStateError);
  });

  testWidgets('dashboard registers and selects a new business', (tester) async {
    final storeRepository = MemorySellerStoreRepository(stores: []);
    final selectionStore = MemorySellerStoreSelectionStore();
    await tester.pumpWidget(
      PopqSellerApp(
        environment: const AppEnvironment.local(),
        sessionStore: _validSessionStore(),
        storeSelectionStore: selectionStore,
        storeRepository: storeRepository,
        identityRepository: const MemorySellerIdentityRepository(),
        orderRepository: MemorySellerOrderRepository(),
        productRepository: MemorySellerProductRepository(),
        analyticsRepository: MemorySellerAnalyticsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('등록된 사업장이 없어요.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-store')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('store-name')), '신규 강남 사업장');
    await tester.tap(find.byKey(const Key('submit-store')));
    await tester.pumpAndSettle();

    expect(find.text('신규 강남 사업장'), findsOneWidget);
    expect(await selectionStore.read(), 1);
    expect((await storeRepository.findAll()).single.name, '신규 강남 사업장');
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
  String status = 'PLACED',
  int version = 1,
}) {
  return SellerOrder(
    orderPublicId: orderPublicId,
    storeId: storeId,
    storeName: storeName,
    orderType: 'TAKEOUT',
    status: status,
    subtotalAmount: 6500,
    discountAmount: 0,
    taxAmount: 0,
    serviceFeeAmount: 0,
    totalAmount: 6500,
    version: version,
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

SellerProduct _product({
  required int productId,
  required int storeId,
  required String name,
}) {
  return SellerProduct(
    productId: productId,
    storeId: storeId,
    categoryId: 1,
    categoryName: '커피',
    name: name,
    basePrice: 4500,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
    availableForCustomerApp: true,
    qrWebEnabled: true,
    customerAppEnabled: true,
  );
}
