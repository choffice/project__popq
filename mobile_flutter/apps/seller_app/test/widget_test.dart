import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_seller_app/src/features/auth/seller_identity_repository.dart';
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('성수 커피 연구소'), findsOneWidget);
    expect(find.text('영업 준비'), findsOneWidget);

    await tester.tap(find.text('주문'));
    await tester.pumpAndSettle();
    expect(find.text('신규 주문'), findsWidgets);
    expect(find.textContaining('9.6B'), findsOneWidget);
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
