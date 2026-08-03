import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/announcements/seller_announcement_repository.dart';
import 'features/auth/seller_auth_repository.dart';
import 'features/auth/seller_bootstrap_controller.dart';
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
    this.themeController,
    this.authRepository,
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
  final PopqThemeController? themeController;
  final SellerAuthRepository? authRepository;

  @override
  State<PopqSellerApp> createState() =>
      _PopqSellerAppState();
}

class _PopqSellerAppState extends State<PopqSellerApp> {
  late final SessionStore _sessionStore;
  late final SessionController _sessionController;

  late final SellerStoreSelectionController
  _storeSelectionController;

  late final SellerBootstrapController
  _bootstrapController;

  late final SellerStoreRepository _storeRepository;

  late final SellerAnnouncementRepository
  _announcementRepository;

  late final SellerOrderRepository _orderRepository;
  late final SellerProductRepository _productRepository;

  late final SellerAnalyticsRepository
  _analyticsRepository;

  late final SellerAuthRepository _authRepository;

  late final PopqThemeController _themeController;
  late final bool _ownsThemeController;

  late final PopqApiClient _apiClient;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    final useMemoryStorage =
        kIsWeb &&
            widget.environment.flavor ==
                AppFlavor.development;

    _sessionStore =
        widget.sessionStore ??
            (useMemoryStorage
                ? MemorySessionStore()
                : SecureSessionStore(
              storageKey:
              'popq.seller.auth.session.v1',
            ));

    _sessionController = SessionController(
      sessionStore: _sessionStore,
    );

    _storeSelectionController =
        SellerStoreSelectionController(
          widget.storeSelectionStore ??
              (useMemoryStorage
                  ? MemorySellerStoreSelectionStore()
                  : SharedPreferencesSellerStoreSelectionStore()),
        );

    _ownsThemeController =
        widget.themeController == null;

    _themeController =
        widget.themeController ??
            PopqThemeController(
              storageKey:
              'popq.seller.theme.preference.v1',
            );

    _apiClient = PopqApiClient(
      baseUrl: widget.environment.apiBaseUrl,
      accessTokenReader: () async {
        final session = await _sessionStore.read();
        return session?.accessToken;
      },
    );

    _storeRepository =
        widget.storeRepository ??
            ApiSellerStoreRepository(_apiClient);

    _announcementRepository =
        widget.announcementRepository ??
            ApiSellerAnnouncementRepository(_apiClient);

    _orderRepository =
        widget.orderRepository ??
            ApiSellerOrderRepository(_apiClient);

    _productRepository =
        widget.productRepository ??
            ApiSellerProductRepository(_apiClient);

    _analyticsRepository =
        widget.analyticsRepository ??
            ApiSellerAnalyticsRepository(_apiClient);

    final identityRepository =
        widget.identityRepository ??
            ApiSellerIdentityRepository(_apiClient);

    _authRepository =
        widget.authRepository ??
            ApiSellerAuthRepository(_apiClient);

    _bootstrapController =
        SellerBootstrapController(
          sessionController: _sessionController,
          storeSelectionController:
          _storeSelectionController,
          identityRepository: identityRepository,
        );

    _router = createSellerRouter(
      sessionController: _sessionController,
      bootstrapController: _bootstrapController,
      storeSelectionController:
      _storeSelectionController,
      storeRepository: _storeRepository,
      announcementRepository:
      _announcementRepository,
      orderRepository: _orderRepository,
      productRepository: _productRepository,
      analyticsRepository:
      _analyticsRepository,
      onSignOut: _bootstrapController.signOut,
      onSignIn: _signIn,
      onSignUp: _signUp,
      themeController: _themeController,
      onDevelopmentSignIn:
      widget.environment.flavor ==
          AppFlavor.development
          ? _developmentSignIn
          : null,
    );

    unawaited(
      Future.wait([
        _bootstrapController.restore(),
        _themeController.restore(),
      ]),
    );
  }

  Future<void> _signIn(String email, String password) async {
    final result = await _authRepository.logIn(
      email: email,
      password: password,
    );
    await _completeSignIn(result.session);
  }

  Future<void> _signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    final result = await _authRepository.signUp(
      email: email,
      password: password,
      name: name,
      phone: phone,
    );
    await _completeSignIn(result.session);
  }

  Future<void> _completeSignIn(AuthSession session) async {
    await _storeSelectionController.clear();
    await _sessionController.save(session);
    _bootstrapController.acknowledgeSellerSignIn();

    final stores = await _storeRepository.findAll();
    if (stores.length == 1) {
      await _storeSelectionController.select(stores.single.storeId);
    }
  }

  Future<void> _developmentSignIn() async {
    final response =
    await _apiClient.post<Map<String, Object?>>(
      '/api/v1/dev/auth/login',
      body: {
        'email': 'seller@popq.local',
        'name': 'POPQ 테스트 판매자',
        'role': 'SELLER',
      },
      decode: (value) {
        return Map<String, Object?>.from(
          value as Map,
        );
      },
    );

    final user = Map<String, Object?>.from(
      response['user'] as Map,
    );

    if (user['role'] != 'SELLER') {
      throw StateError(
        'seller role is required',
      );
    }

    final expiresIn =
    (response['expiresIn'] as num).toInt();

    await _storeSelectionController.clear();

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

    _bootstrapController
        .acknowledgeSellerSignIn();

    final stores =
    await _storeRepository.findAll();

    if (stores.isEmpty) {
      final created =
      await _storeRepository
          .createDevelopmentStore();

      await _storeSelectionController.select(
        created.storeId,
      );
    } else if (stores.length == 1) {
      await _storeSelectionController.select(
        stores.single.storeId,
      );
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _apiClient.close();
    _bootstrapController.dispose();
    _storeSelectionController.dispose();
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
          title: 'POPQ Seller',
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