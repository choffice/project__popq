import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/auth/seller_bootstrap_controller.dart';
import 'features/announcements/seller_announcement_repository.dart';
import 'features/auth/seller_identity_repository.dart';
import 'features/home/seller_analytics_repository.dart';
import 'features/orders/seller_order_repository.dart';
import 'features/products/seller_product_repository.dart';
import 'features/stores/seller_store_repository.dart';
import 'features/stores/seller_store_selection_controller.dart';
import 'features/stores/seller_store_selection_store.dart';
import 'routing/seller_router.dart';

class PopqSellerApp extends StatefulWidget {
  const PopqSellerApp({
    required this.environment,
    this.sessionStore,
    this.storeSelectionStore,
    this.storeRepository,
    this.announcementRepository,
    this.identityRepository,
    this.orderRepository,
    this.productRepository,
    this.analyticsRepository,
    super.key,
  });

  final AppEnvironment environment;
  final SessionStore? sessionStore;
  final SellerStoreSelectionStore? storeSelectionStore;
  final SellerStoreRepository? storeRepository;
  final SellerAnnouncementRepository? announcementRepository;
  final SellerIdentityRepository? identityRepository;
  final SellerOrderRepository? orderRepository;
  final SellerProductRepository? productRepository;
  final SellerAnalyticsRepository? analyticsRepository;

  @override
  State<PopqSellerApp> createState() => _PopqSellerAppState();
}

class _PopqSellerAppState extends State<PopqSellerApp> {
  late final SessionStore _sessionStore;
  late final SessionController _sessionController;
  late final SellerStoreSelectionController _storeSelectionController;
  late final SellerBootstrapController _bootstrapController;
  late final SellerStoreRepository _storeRepository;
  late final SellerAnnouncementRepository _announcementRepository;
  late final SellerOrderRepository _orderRepository;
  late final SellerProductRepository _productRepository;
  late final SellerAnalyticsRepository _analyticsRepository;
  late final PopqApiClient _apiClient;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _sessionStore =
        widget.sessionStore ??
        SecureSessionStore(storageKey: 'popq.seller.auth.session.v1');
    _sessionController = SessionController(sessionStore: _sessionStore);
    _storeSelectionController = SellerStoreSelectionController(
      widget.storeSelectionStore ??
          SharedPreferencesSellerStoreSelectionStore(),
    );
    _apiClient = PopqApiClient(
      baseUrl: widget.environment.apiBaseUrl,
      accessTokenReader: () async => (await _sessionStore.read())?.accessToken,
    );
    _storeRepository =
        widget.storeRepository ?? ApiSellerStoreRepository(_apiClient);
    _announcementRepository =
        widget.announcementRepository ??
        ApiSellerAnnouncementRepository(_apiClient);
    _orderRepository =
        widget.orderRepository ?? ApiSellerOrderRepository(_apiClient);
    _productRepository =
        widget.productRepository ?? ApiSellerProductRepository(_apiClient);
    _analyticsRepository =
        widget.analyticsRepository ?? ApiSellerAnalyticsRepository(_apiClient);
    final identityRepository =
        widget.identityRepository ?? ApiSellerIdentityRepository(_apiClient);
    _bootstrapController = SellerBootstrapController(
      sessionController: _sessionController,
      storeSelectionController: _storeSelectionController,
      identityRepository: identityRepository,
    );
    _router = createSellerRouter(
      sessionController: _sessionController,
      bootstrapController: _bootstrapController,
      storeSelectionController: _storeSelectionController,
      storeRepository: _storeRepository,
      announcementRepository: _announcementRepository,
      orderRepository: _orderRepository,
      productRepository: _productRepository,
      analyticsRepository: _analyticsRepository,
      onSignOut: _bootstrapController.signOut,
      onDevelopmentSignIn: widget.environment.flavor == AppFlavor.development
          ? _developmentSignIn
          : null,
    );
    unawaited(_bootstrapController.restore());
  }

  Future<void> _developmentSignIn() async {
    final response = await _apiClient.post<Map<String, Object?>>(
      '/api/v1/dev/auth/login',
      body: {
        'email': 'seller-app-dev@popq.local',
        'name': 'POPQ 개발 판매자',
        'role': 'SELLER',
      },
      decode: (value) => Map<String, Object?>.from(value as Map),
    );
    final user = Map<String, Object?>.from(response['user'] as Map);
    if (user['role'] != 'SELLER') {
      throw StateError('seller role is required');
    }

    final expiresIn = (response['expiresIn'] as num).toInt();
    await _storeSelectionController.clear();
    await _sessionController.save(
      AuthSession(
        accessToken: response['accessToken'] as String,
        refreshToken: '',
        expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      ),
    );
    _bootstrapController.acknowledgeSellerSignIn();

    final stores = await _storeRepository.findAll();
    if (stores.isEmpty) {
      final created = await _storeRepository.createDevelopmentStore();
      await _storeSelectionController.select(created.storeId);
    } else if (stores.length == 1) {
      await _storeSelectionController.select(stores.single.storeId);
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _apiClient.close();
    _bootstrapController.dispose();
    _storeSelectionController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'POPQ Seller',
      debugShowCheckedModeBanner: !widget.environment.isProduction,
      theme: PopqTheme.light(),
      routerConfig: _router,
    );
  }
}
