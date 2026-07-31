import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'routing/customer_router.dart';
import 'features/discovery/store_discovery_repository.dart';
import 'features/cart/cart_controller.dart';
import 'features/catalog/catalog_repository.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/onboarding/onboarding_store.dart';
import 'features/notifications/customer_notification_repository.dart';
import 'features/orders/customer_order_repository.dart';
import 'features/permissions/customer_permission_gateway.dart';
import 'features/profile/customer_engagement_repository.dart';

class PopqCustomerApp extends StatefulWidget {
  const PopqCustomerApp({
    required this.environment,
    this.sessionStore,
    this.onboardingStore,
    this.storeDiscoveryRepository,
    this.catalogRepository,
    this.orderRepository,
    this.engagementRepository,
    this.notificationRepository,
    this.cartController,
    this.permissionGateway,
    super.key,
  });

  final AppEnvironment environment;
  final SessionStore? sessionStore;
  final OnboardingStore? onboardingStore;
  final StoreDiscoveryRepository? storeDiscoveryRepository;
  final CatalogRepository? catalogRepository;
  final CustomerOrderRepository? orderRepository;
  final CustomerEngagementRepository? engagementRepository;
  final CustomerNotificationRepository? notificationRepository;
  final CartController? cartController;
  final CustomerPermissionGateway? permissionGateway;

  @override
  State<PopqCustomerApp> createState() => _PopqCustomerAppState();
}

class _PopqCustomerAppState extends State<PopqCustomerApp> {
  late final SessionController _sessionController;
  late final OnboardingController _onboardingController;
  late final SessionStore _sessionStore;
  late final PopqApiClient _apiClient;
  late final CartController _cartController;
  late final GoRouter _router;
  late final GoogleAuthService _googleAuthService;

  @override
  void initState() {
    super.initState();
    _sessionStore = widget.sessionStore ?? SecureSessionStore();
    _sessionController = SessionController(sessionStore: _sessionStore);
    _onboardingController = OnboardingController(
      widget.onboardingStore ?? SharedPreferencesOnboardingStore(),
    );
    _apiClient = PopqApiClient(
      baseUrl: widget.environment.apiBaseUrl,
      accessTokenReader: () async => (await _sessionStore.read())?.accessToken,
    );
    _googleAuthService = GoogleAuthService(
      webClientId: '977349461588-b8tqabapb8k86gkok0qd6lem7jjd5r8i.apps.googleusercontent.com',
    );
    final permissionGateway =
        widget.permissionGateway ?? DeviceCustomerPermissionGateway();
    final repository =
        widget.storeDiscoveryRepository ??
        ApiStoreDiscoveryRepository(_apiClient);
    final catalogRepository =
        widget.catalogRepository ?? ApiCatalogRepository(_apiClient);
    final orderRepository =
        widget.orderRepository ?? ApiCustomerOrderRepository(_apiClient);
    final engagementRepository =
        widget.engagementRepository ??
        ApiCustomerEngagementRepository(_apiClient);
    final notificationRepository =
        widget.notificationRepository ??
        ApiCustomerNotificationRepository(_apiClient);
    _cartController = widget.cartController ?? CartController();
    _router = createCustomerRouter(
      sessionController: _sessionController,
      onboardingController: _onboardingController,
      storeDiscoveryRepository: repository,
      catalogRepository: catalogRepository,
      orderRepository: orderRepository,
      engagementRepository: engagementRepository,
      notificationRepository: notificationRepository,
      cartController: _cartController,
      permissionGateway: permissionGateway,
      onDevelopmentSignIn: widget.environment.flavor == AppFlavor.development
          ? _developmentSignIn
          : null,
      onGoogleSignIn: _googleSignIn,
    );

    unawaited(
      Future.wait([
        _sessionController.restore(),
        _onboardingController.restore(),
      ]),
    );
  }

  Future<void> _developmentSignIn() async {
    final response = await _apiClient.post<Map<String, Object?>>(
      '/api/v1/dev/auth/login',
      body: {
        'email': 'customer-app-dev@popq.local',
        'name': 'POPQ 개발 고객',
        'role': 'CUSTOMER',
      },
      decode: (value) => Map<String, Object?>.from(value as Map),
    );
    final expiresIn = (response['expiresIn'] as num).toInt();
    await _sessionController.save(
      AuthSession(
        accessToken: response['accessToken'] as String,
        refreshToken: '',
        expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      ),
    );
  }
  Future<void> _googleSignIn() async {
    final idToken = await _googleAuthService.signInAndGetIdToken();
    debugPrint('Google idToken: $idToken');
    // TODO(backend): Spring Security 엔드포인트 확정되면
    // idToken을 body에 담아 POST 요청 → 응답의 accessToken/refreshToken을
    // _sessionController.save(AuthSession(...))에 저장하는 코드로 교체
  }

  @override
  void dispose() {
    _router.dispose();
    _apiClient.close();
    _cartController.dispose();
    _onboardingController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'POPQ',
      debugShowCheckedModeBanner: !widget.environment.isProduction,
      theme: PopqTheme.light(),
      routerConfig: _router,
    );
  }
}
