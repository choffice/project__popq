import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_customer_app/src/customer_app.dart';
import 'package:popq_customer_app/src/features/catalog/catalog_repository.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_repository.dart';
import 'package:popq_customer_app/src/features/notifications/customer_notification_repository.dart';
import 'package:popq_customer_app/src/features/onboarding/onboarding_store.dart';
import 'package:popq_customer_app/src/features/orders/customer_order_repository.dart';
import 'package:popq_customer_app/src/features/permissions/customer_permission_gateway.dart';
import 'package:popq_customer_app/src/features/profile/customer_engagement_repository.dart';

void main() {
  testWidgets('first launch completes optional permission onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        splashMinDuration: Duration.zero,
        sessionStore: MemorySessionStore(),
        onboardingStore: MemoryOnboardingStore(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        engagementRepository: MemoryCustomerEngagementRepository(),
        notificationRepository: MemoryCustomerNotificationRepository(),
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
        splashMinDuration: Duration.zero,
        sessionStore: MemorySessionStore(),
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        engagementRepository: MemoryCustomerEngagementRepository(),
        notificationRepository: MemoryCustomerNotificationRepository(),
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
    expect(find.text('매장 상세'), findsOneWidget);
    expect(find.text('서울 성동구 연무장길'), findsOneWidget);
  });

  testWidgets('protected order route redirects a signed-out user', (
    tester,
  ) async {
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        splashMinDuration: Duration.zero,
        sessionStore: MemorySessionStore(),
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        engagementRepository: MemoryCustomerEngagementRepository(),
        notificationRepository: MemoryCustomerNotificationRepository(),
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
        splashMinDuration: Duration.zero,
        sessionStore: sessionStore,
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        orderRepository: MemoryCustomerOrderRepository(),
        engagementRepository: MemoryCustomerEngagementRepository(),
        notificationRepository: MemoryCustomerNotificationRepository(),
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
        splashMinDuration: Duration.zero,
        sessionStore: sessionStore,
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        catalogRepository: MemoryCatalogRepository(),
        orderRepository: orderRepository,
        engagementRepository: MemoryCustomerEngagementRepository(),
        notificationRepository: MemoryCustomerNotificationRepository(),
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
        splashMinDuration: Duration.zero,
        sessionStore: const _FailingSessionStore(),
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        engagementRepository: MemoryCustomerEngagementRepository(),
        notificationRepository: MemoryCustomerNotificationRepository(),
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('잠시 문제가 생겼어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('signed-in customer sees interests reviews and profile counts', (
    tester,
  ) async {
    final engagementRepository = MemoryCustomerEngagementRepository(
      profile: const CustomerProfile(
        userId: 7,
        email: 'tester@popq.test',
        name: 'POPQ 테스터',
        interestCount: 1,
        reviewCount: 1,
        orderCount: 3,
      ),
      interests: const [
        InterestedStore(
          storeId: 1,
          name: '단골 카페',
          businessStatus: 'OPEN',
          address: '서울 성동구',
        ),
      ],
      reviews: [
        CustomerReview(
          reviewId: 1,
          orderPublicId: 'order-1',
          storeId: 1,
          storeName: '단골 카페',
          authorName: 'POPQ 테스터',
          rating: 5,
          content: '다시 주문할게요.',
          status: 'ACTIVE',
          createdAt: DateTime(2026),
        ),
      ],
    );
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        splashMinDuration: Duration.zero,
        sessionStore: MemorySessionStore(
          AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        orderRepository: MemoryCustomerOrderRepository(),
        engagementRepository: engagementRepository,
        notificationRepository: MemoryCustomerNotificationRepository(),
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();

    expect(find.text('POPQ 테스터'), findsOneWidget);
    expect(find.text('단골 카페'), findsNWidgets(2));
    expect(find.text('다시 주문할게요.'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('notification opens order detail and marks itself read', (
    tester,
  ) async {
    final notificationRepository = MemoryCustomerNotificationRepository(
      notifications: [
        CustomerNotification(
          notificationId: 1,
          type: 'ORDER_STATUS',
          targetType: 'ORDER',
          targetId: 'memory-order-1',
          title: '주문 상품이 준비됐어요',
          message: '스토어에서 상품을 수령해 주세요.',
          deepLink: '/orders/memory-order-1',
          read: false,
          occurredAt: DateTime(2026, 7, 29, 17, 30),
        ),
      ],
    );
    final orderRepository = MemoryCustomerOrderRepository(
      orders: const [
        CustomerOrder(
          orderPublicId: 'memory-order-1',
          storeId: 1,
          storeName: '단골 카페',
          status: 'READY',
          totalAmount: 5000,
          version: 4,
          items: [
            CustomerOrderItem(
              productName: '아메리카노',
              quantity: 1,
              itemTotalPrice: 5000,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      PopqCustomerApp(
        environment: const AppEnvironment.local(),
        splashMinDuration: Duration.zero,
        sessionStore: MemorySessionStore(
          AuthSession(
            accessToken: 'access',
            refreshToken: 'refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
        onboardingStore: MemoryOnboardingStore.complete(),
        storeDiscoveryRepository: MemoryStoreDiscoveryRepository(),
        orderRepository: orderRepository,
        engagementRepository: MemoryCustomerEngagementRepository(),
        notificationRepository: notificationRepository,
        permissionGateway: MemoryCustomerPermissionGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byTooltip('알림'));
    await tester.pumpAndSettle();

    expect(find.text('주문 상품이 준비됐어요'), findsOneWidget);
    await tester.tap(find.text('주문 상품이 준비됐어요'));
    await tester.pumpAndSettle();

    expect(find.text('주문 상세'), findsOneWidget);
    expect(find.text('준비가 완료됐어요'), findsOneWidget);
    expect(await notificationRepository.unreadCount(), 0);
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
