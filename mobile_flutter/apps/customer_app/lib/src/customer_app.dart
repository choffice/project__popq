import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/cart/cart_controller.dart';
import 'features/catalog/catalog_repository.dart';
import 'features/discovery/store_discovery_repository.dart';
import 'features/notifications/customer_notification_repository.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/onboarding/onboarding_store.dart';
import 'features/orders/customer_order_repository.dart';
import 'features/permissions/customer_permission_gateway.dart';
import 'features/profile/customer_engagement_repository.dart';
import 'routing/customer_router.dart';

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
    this.themeController,
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
  final PopqThemeController? themeController;

  @override
  State<PopqCustomerApp> createState() =>
      _PopqCustomerAppState();
}

class _PopqCustomerAppState extends State<PopqCustomerApp> {
  late final SessionController _sessionController;
  late final OnboardingController _onboardingController;
  late final SessionStore _sessionStore;
  late final PopqApiClient _apiClient;
  late final CartController _cartController;
  late final PopqThemeController _themeController;
  late final bool _ownsThemeController;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _sessionStore =
        widget.sessionStore ?? SecureSessionStore();

    _sessionController = SessionController(
      sessionStore: _sessionStore,
    );

    _onboardingController = OnboardingController(
      widget.onboardingStore ??
          SharedPreferencesOnboardingStore(),
    );

    _ownsThemeController =
        widget.themeController == null;

    _themeController =
        widget.themeController ??
            PopqThemeController();

    _apiClient = PopqApiClient(
      baseUrl: widget.environment.apiBaseUrl,
      accessTokenReader: () async {
        return (await _sessionStore.read())
            ?.accessToken;
      },
    );

    final permissionGateway =
        widget.permissionGateway ??
            DeviceCustomerPermissionGateway();

    final storeDiscoveryRepository =
        widget.storeDiscoveryRepository ??
            ApiStoreDiscoveryRepository(_apiClient);

    final catalogRepository =
        widget.catalogRepository ??
            ApiCatalogRepository(_apiClient);

    final orderRepository =
        widget.orderRepository ??
            ApiCustomerOrderRepository(_apiClient);

    final engagementRepository =
        widget.engagementRepository ??
            ApiCustomerEngagementRepository(_apiClient);

    final notificationRepository =
        widget.notificationRepository ??
            ApiCustomerNotificationRepository(_apiClient);

    _cartController =
        widget.cartController ??
            CartController();

    _router = createCustomerRouter(
      sessionController: _sessionController,
      onboardingController:
      _onboardingController,
      storeDiscoveryRepository:
      storeDiscoveryRepository,
      catalogRepository: catalogRepository,
      orderRepository: orderRepository,
      engagementRepository:
      engagementRepository,
      notificationRepository:
      notificationRepository,
      cartController: _cartController,
      permissionGateway: permissionGateway,
      tossClientKey:
      widget.environment.tossClientKey,
      themeController: _themeController,
      onDevelopmentSignIn:
      widget.environment.flavor ==
          AppFlavor.development
          ? _developmentSignIn
          : null,
    );

    unawaited(
      Future.wait([
        _sessionController.restore(),
        _onboardingController.restore(),
        _themeController.restore(),
      ]),
    );
  }

  Future<void> _developmentSignIn() async {
    final response =
    await _apiClient.post<Map<String, Object?>>(
      '/api/v1/dev/auth/login',
      body: {
        'email':
        'customer-app-dev@popq.local',
        'name': 'POPQ 개발 고객',
        'role': 'CUSTOMER',
      },
      decode: (value) {
        return Map<String, Object?>.from(
          value as Map,
        );
      },
    );

    final expiresIn =
    (response['expiresIn'] as num).toInt();

    await _sessionController.save(
      AuthSession(
        accessToken:
        response['accessToken'] as String,
        refreshToken: '',
        expiresAt: DateTime.now()
            .toUtc()
            .add(
          Duration(seconds: expiresIn),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _apiClient.close();
    _cartController.dispose();
    _onboardingController.dispose();
    _sessionController.dispose();

    if (_ownsThemeController) {
      _themeController.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'POPQ',
          debugShowCheckedModeBanner:
          !widget.environment.isProduction,
          theme: PopqTheme.light(),
          darkTheme: PopqTheme.dark(),
          themeMode:
          _themeController.themeMode,
          routerConfig: _router,
        );
      },
    );
  }
}