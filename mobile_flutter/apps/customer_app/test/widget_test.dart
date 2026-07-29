import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_customer_app/src/customer_app.dart';
import 'package:popq_customer_app/src/features/catalog/catalog_repository.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_repository.dart';
import 'package:popq_customer_app/src/features/onboarding/onboarding_store.dart';
import 'package:popq_customer_app/src/features/orders/customer_order_repository.dart';
import 'package:popq_customer_app/src/features/permissions/customer_permission_gateway.dart';

void main() {
  testWidgets('first launch completes optional permission onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        sessionStore: MemorySessionStore(),
        onboardingStore: MemoryOnboardingStore(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('좋아할 만한 곳'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('가까운 순서'), findsOneWidget);

    await tester.tap(find.text('위치 허용하고 계속'));
    await tester.pumpAndSettle();
    expect(find.textContaining('주문과 관심 매장'), findsOneWidget);

    await tester.tap(find.text('알림 허용하고 완료'));
    await tester.pumpAndSettle();
    expect(find.textContaining('지금 가까운 곳'), findsOneWidget);
  });

  testWidgets('customer filters stores and opens a public detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        sessionStore: MemorySessionStore(),
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    expect(find.text('성수 커피 연구소'), findsOneWidget);
    expect(find.text('주말 디저트 마켓'), findsOneWidget);

    await tester.tap(find.text('#coffee').first);
    await tester.pumpAndSettle();
    expect(find.text('성수 커피 연구소'), findsOneWidget);
    expect(find.text('주말 디저트 마켓'), findsNothing);

    await tester.tap(find.text('성수 커피 연구소'));
    await tester.pumpAndSettle();
    expect(find.text('스토어 상세'), findsOneWidget);
    expect(find.text('서울 성동구 연무장길'), findsOneWidget);
  });

  testWidgets('protected order route redirects a signed-out user', (
    tester,
  ) async {
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        sessionStore: MemorySessionStore(),
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('주문'));
    await tester.pumpAndSettle();

    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.textContaining('POPQ를 이어서'), findsOneWidget);
  });

  testWidgets('restored session opens protected order route', (tester) async {
    final sessionStore = MemorySessionStore(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        sessionStore: sessionStore,
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        orderRepository: MemoryCustomerOrderRepository(),
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('주문'));
    await tester.pumpAndSettle();

    expect(find.text('주문 내역'), findsWidgets);
    expect(find.text('아직 주문 내역이 없어요.'), findsOneWidget);
  });

  testWidgets('customer selects options pays and restores the order', (
    tester,
  ) async {
    final sessionStore = MemorySessionStore(
      AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final orderRepository = MemoryCustomerOrderRepository();
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        sessionStore: sessionStore,
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        catalogRepository: MemoryCatalogRepository(),
        orderRepository: orderRepository,
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('탐색'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('성수 커피 연구소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('상품 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아메리카노'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아이스'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('장바구니 담기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();

    expect(find.text('장바구니'), findsOneWidget);
    expect(find.text('5,500원'), findsWidgets);

    await tester.tap(find.textContaining('주문하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('5,500원 결제'));
    await tester.pumpAndSettle();

    expect(find.text('주문 상세'), findsOneWidget);
    expect(find.text('주문 접수 대기'), findsOneWidget);
    expect(find.text('성수 커피 연구소'), findsOneWidget);
  });

  testWidgets('session restore failure renders a retry state', (tester) async {
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        sessionStore: const _FailingSessionStore(),
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('잠시 문제가 생겼어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });
}

class _FailingSessionStore implements SessionStore {
  const _FailingSessionStore();

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    throw StateError('secure storage unavailable');
  }

  @override
  Future<void> write(AuthSession session) async {}
}
