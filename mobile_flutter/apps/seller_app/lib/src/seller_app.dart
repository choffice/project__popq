import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:popq_design_system/popq_design_system.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';

import 'features/announcements/seller_announcement_repository.dart';
import 'features/auth/seller_auth_repository.dart';
import 'features/auth/kakao_auth_service.dart';
import 'features/auth/naver_auth_service.dart';
import 'features/auth/seller_bootstrap_controller.dart';
import 'features/auth/seller_identity_repository.dart';
import 'features/customers/seller_customer_repository.dart';
import 'features/home/seller_analytics_repository.dart';
import 'features/notifications/seller_operational_alert_repository.dart';
import 'features/orders/seller_order_repository.dart';
import 'features/products/seller_product_repository.dart';
import 'features/reviews/seller_review_repository.dart';
import 'features/stores/seller_store_repository.dart';
import 'features/stores/seller_store_selection_controller.dart';
import 'features/stores/seller_store_selection_store.dart';
import 'notifications/seller_push_device_repository.dart';
import 'notifications/seller_push_notification_service.dart';
import 'realtime/seller_realtime_scope.dart';
import 'routing/seller_router.dart';
import 'theme/seller_theme.dart';

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
    this.customerRepository,
    this.reviewRepository,
    this.operationalAlertRepository,
    this.themeController,
    this.authRepository,
    this.splashMinDuration = const Duration(seconds: 3),
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
  final SellerCustomerRepository? customerRepository;
  final SellerReviewRepository? reviewRepository;
  final SellerOperationalAlertRepository? operationalAlertRepository;
  final PopqThemeController? themeController;
  final SellerAuthRepository? authRepository;

  /// ?ㅽ뵆?섏떆 ?붾㈃(遺?몄뒪?몃옪)??理쒖냼 ???쒓컙留뚰겮 蹂댁뿬以띾땲??
  ///
  /// ?꾩젽 ?뚯뒪?몄뿉?쒕뒗 [Duration.zero]濡??섍꺼???ㅽ뵆?섏떆瑜?嫄대꼫?????덉뒿?덈떎.
  final Duration splashMinDuration;

  @override
  State<PopqSellerApp> createState() {
    return _PopqSellerAppState();
  }
}

class _PopqSellerAppState extends State<PopqSellerApp>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final SessionStore _sessionStore;
  late final SessionController _sessionController;

  late final SellerStoreSelectionController _storeSelectionController;

  late final SellerBootstrapController _bootstrapController;

  late final SellerStoreRepository _storeRepository;

  late final SellerAnnouncementRepository _announcementRepository;

  late final SellerOrderRepository _orderRepository;

  late final SellerProductRepository _productRepository;

  late final SellerAnalyticsRepository _analyticsRepository;

  late final SellerCustomerRepository _customerRepository;
  late final SellerReviewRepository _reviewRepository;
  late final SellerOperationalAlertRepository _operationalAlertRepository;

  late final SellerAuthRepository _authRepository;

  late final PopqThemeController _themeController;

  late final GoogleAuthService _googleAuthService;

  late final KakaoAuthService _kakaoAuthService;

  late final NaverAuthService _naverAuthService;

  late final bool _ownsThemeController;

  late final PopqApiClient _apiClient;

  late final SellerPushDeviceRepository _pushDeviceRepository;

  late final PopqRealtimeClient _realtimeClient;

  late final GoRouter _router;

  late final _SellerBackButtonDispatcher _backButtonDispatcher;

  bool _isAppActive = true;
  String? _pendingPushDeepLink;
  bool _openingPushDeepLink = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    final useMemoryStorage =
        kIsWeb && widget.environment.flavor == AppFlavor.development;

    // ?ㅼ갹
    final isWebDevelopment =
        kIsWeb && widget.environment.flavor == AppFlavor.development;

    _sessionStore =
        widget.sessionStore ??
        (useMemoryStorage
            ? MemorySessionStore()
            : SecureSessionStore(storageKey: 'popq.seller.auth.session.v1'));

    _sessionController = SessionController(sessionStore: _sessionStore);

    _storeSelectionController = SellerStoreSelectionController(
      widget.storeSelectionStore ??
          (useMemoryStorage
              ? MemorySellerStoreSelectionStore()
              : SharedPreferencesSellerStoreSelectionStore()),
    );

    _ownsThemeController = widget.themeController == null;

    _themeController =
        widget.themeController ??
        PopqThemeController(storageKey: 'popq.seller.theme.preference.v1');

    _apiClient = PopqApiClient(
      baseUrl: widget.environment.apiBaseUrl,
      accessTokenReader: () async {
        final session = await _sessionStore.read();

        return session?.accessToken;
      },
    );

    _pushDeviceRepository = SellerPushDeviceRepository(_apiClient);

    _realtimeClient = PopqRealtimeClient(
      webSocketUri: widget.environment.realtimeWebSocketUri,
      accessTokenReader: () async {
        return _sessionController.accessToken;
      },
      enableLogs: widget.environment.enableNetworkLogs,
    );

    _sessionController.addListener(_handleSessionChanged);

    //?ㅼ갹
    if (!(kIsWeb &&
    widget.environment.flavor == AppFlavor.development)) {
      _googleAuthService = GoogleAuthService(
        webClientId:
        '977349461588-b8tqabapb8k86gkok0qd6lem7jjd5r8i.apps.googleusercontent.com',
      );

      _kakaoAuthService = KakaoAuthService();

      _naverAuthService = NaverAuthService();
    }

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

    _customerRepository =
        widget.customerRepository ?? ApiSellerCustomerRepository(_apiClient);

    _reviewRepository =
        widget.reviewRepository ?? ApiSellerReviewRepository(_apiClient);

    _operationalAlertRepository = widget.operationalAlertRepository ??
        ApiSellerOperationalAlertRepository(_apiClient);

    final identityRepository =
        widget.identityRepository ??
            ApiSellerIdentityRepository(
              _apiClient,
              imageBaseUrl: widget.environment.apiBaseUrl,
            );

    _authRepository =
        widget.authRepository ?? ApiSellerAuthRepository(_apiClient);

    _bootstrapController = SellerBootstrapController(
      sessionController: _sessionController,
      storeSelectionController: _storeSelectionController,
      identityRepository: identityRepository,
    );

    _bootstrapController.addListener(_handleBootstrapChanged);

    _router = createSellerRouter(
      sessionController: _sessionController,
      bootstrapController: _bootstrapController,
      storeSelectionController: _storeSelectionController,
      storeRepository: _storeRepository,
      announcementRepository: _announcementRepository,
      orderRepository: _orderRepository,
      productRepository: _productRepository,
      analyticsRepository: _analyticsRepository,
      customerRepository: _customerRepository,
      reviewRepository: _reviewRepository,
      operationalAlertRepository: _operationalAlertRepository,
      onSignOut: _bootstrapController.signOut,
      onWithdraw: _withdraw,
      onConnectCustomerAccess: _connectCustomerAccess,
      onSignIn: _signIn,
      onSignUp: _signUp,
      onFindId: _findId,
      onVerifyForPasswordReset: _verifyForPasswordReset,
      onResetPassword: _resetPassword,
      themeController: _themeController,
      onDevelopmentSignIn: widget.environment.flavor == AppFlavor.development
          ? _developmentSignIn
          : null,
      onGoogleSignIn: _googleSignIn,
      onKakaoSignIn: _kakaoSignIn,
      onNaverSignIn: _naverSignIn,
      minSplashDuration: widget.splashMinDuration,
    );

    PushNotificationService.setDeepLinkHandler(_handlePushDeepLink);

    _backButtonDispatcher = _SellerBackButtonDispatcher(
      _router,
      _scaffoldMessengerKey,
    );

    unawaited(
      Future.wait([_bootstrapController.restore(), _themeController.restore()]),
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
    required String phone,
  }) async {
    await _authRepository.signUp(
      email: email,
      password: password,
      name: name,
      phone: phone,
    );
  }

  Future<String> _findId(String name, String phone) {
    return _authRepository.findId(name: name, phone: phone);
  }

  Future<void> _verifyForPasswordReset(String email, String phone) {
    return _authRepository.verifyForPasswordReset(email: email, phone: phone);
  }

  Future<void> _resetPassword(String email, String phone, String newPassword) {
    return _authRepository.resetPassword(
      email: email,
      phone: phone,
      newPassword: newPassword,
    );
  }

  Future<void> _withdraw(String? confirmationPhrase) async {
    await _authRepository.withdraw(confirmationPhrase: confirmationPhrase);
    await _bootstrapController.signOut();
  }

  Future<void> _connectCustomerAccess() {
    return _authRepository.connectCustomerAccess();
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

  Future<void> _googleSignIn() async {
    final idToken = await _googleAuthService.signInAndGetIdToken();

    debugPrint(
      '?먮ℓ??Google 濡쒓렇???깃났: ID Token ?섏떊 '
      '(${idToken.length}??',
    );

    final result = await _authRepository.socialLogIn(
      provider: 'GOOGLE',
      providerToken: idToken,
    );

    await _completeSignIn(result.session);
  }

  Future<void> _kakaoSignIn() async {
    final accessToken = await _kakaoAuthService.signInAndGetAccessToken();

    debugPrint(
      '?먮ℓ??Kakao 濡쒓렇???깃났: Access Token ?섏떊 '
      '(${accessToken.length}??',
    );

    final result = await _authRepository.socialLogIn(
      provider: 'KAKAO',
      providerToken: accessToken,
    );

    await _completeSignIn(result.session);
  }

  Future<void> _naverSignIn() async {
    final accessToken = await _naverAuthService.signInAndGetAccessToken();

    debugPrint(
      '?먮ℓ??Naver 濡쒓렇???깃났: Access Token ?섏떊 '
      '(${accessToken.length}??',
    );

    final result = await _authRepository.socialLogIn(
      provider: 'NAVER',
      providerToken: accessToken,
    );

    await _completeSignIn(result.session);
  }

  Future<void> _developmentSignIn() async {
    final response = await _apiClient.post<Map<String, Object?>>(
      '/api/v1/dev/auth/login',
      body: {
        'email': 'map-seed@popq.local',
        'name': 'POPQ 吏???뚯뒪???먮ℓ??,
        'role': 'SELLER',
      },
      decode: (value) {
        return Map<String, Object?>.from(value as Map);
      },
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

  void _handlePushDeepLink(String deepLink) {
    if (!_isSellerChatDeepLink(deepLink)) {
      debugPrint('Seller 吏?먰븯吏 ?딅뒗 ?뚮┝ 寃쎈줈: $deepLink');
      return;
    }

    _pendingPushDeepLink = deepLink;

    unawaited(_openPendingPushDeepLink());
  }

  bool _isSellerChatDeepLink(String deepLink) {
    final uri = Uri.tryParse(deepLink);

    if (uri == null) {
      return false;
    }

    final segments = uri.pathSegments;

    final storeId = int.tryParse(uri.queryParameters['storeId'] ?? '');
    final isChat = segments.length == 2 &&
        segments.first == 'customers' &&
        segments[1].isNotEmpty;
    final isOrder = segments.length == 2 &&
        segments.first == 'orders' &&
        segments[1].isNotEmpty;

    return storeId != null && (isChat || isOrder);
  }

  void _handleBootstrapChanged() {
    unawaited(_openPendingPushDeepLink());
  }

  Future<void> _openPendingPushDeepLink() async {
    if (_openingPushDeepLink) {
      return;
    }

    final deepLink = _pendingPushDeepLink;

    if (deepLink == null ||
        !_sessionController.isSignedIn ||
        _bootstrapController.status != SellerBootstrapStatus.ready) {
      return;
    }

    final uri = Uri.tryParse(deepLink);
    final storeId = int.tryParse(uri?.queryParameters['storeId'] ?? '');

    if (uri == null || storeId == null) {
      _pendingPushDeepLink = null;
      return;
    }

    _openingPushDeepLink = true;

    try {
      if (_storeSelectionController.selectedStoreId != storeId) {
        await _storeSelectionController.select(storeId);
      }

      if (!mounted) {
        return;
      }

      _pendingPushDeepLink = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _router.go(uri.path);
      });
    } catch (error, stackTrace) {
      debugPrint('Seller ?뚮┝ 梨꾪똿 ?대룞 ?ㅽ뙣: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _openingPushDeepLink = false;
    }
  }

  void _handleSessionChanged() {
    if (_sessionController.status == SessionStatus.restoring) {
      return;
    }

    if (!_sessionController.isSignedIn) {
      _realtimeClient.disconnect(clearSubscriptions: true);
      return;
    }

    unawaited(_registerPushDevice());
    unawaited(_openPendingPushDeepLink());

    if (_isAppActive) {
      unawaited(_realtimeClient.connect());
    }
  }

  Future<void> _registerPushDevice() async {
    if (kIsWeb && widget.environment.flavor == AppFlavor.development) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint(
          'Seller ?뚮┝ 沅뚰븳???놁뼱 '
          'FCM 湲곌린瑜??깅줉?섏? ?딆뒿?덈떎.',
        );
        return;
      }

      final token = await messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint(
          'Seller FCM ?좏겙???놁뼱 '
          '湲곌린瑜??깅줉?섏? ?딆뒿?덈떎.',
        );
        return;
      }

      final platform = switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'IOS',
        _ => 'ANDROID',
      };

      final device = await _pushDeviceRepository.registerDevice(
        token: token.trim(),
        platform: platform,
      );

      debugPrint(
        'Seller FCM 湲곌린 ?깅줉 ?꾨즺: '
        'deviceId=${device.deviceId}, '
        'platform=${device.platform}',
      );
    } catch (error, stackTrace) {
      debugPrint('Seller FCM 湲곌린 ?깅줉 ?ㅽ뙣: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;

        if (_sessionController.isSignedIn) {
          unawaited(_realtimeClient.connect());
        }

        return;

      case AppLifecycleState.inactive:
        _isAppActive = false;
        return;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isAppActive = false;
        _realtimeClient.suspend();
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _sessionController.removeListener(_handleSessionChanged);

    _bootstrapController.removeListener(_handleBootstrapChanged);

    PushNotificationService.clearDeepLinkHandler();
    _realtimeClient.dispose();
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
    return SellerRealtimeScope(
      client: _realtimeClient,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, child) {
          return MaterialApp.router(
            title: 'POPQ Seller',
            debugShowCheckedModeBanner: !widget.environment.isProduction,
            scaffoldMessengerKey: _scaffoldMessengerKey,
            theme: SellerTheme.light(),
            darkTheme: SellerTheme.dark(),
            themeMode: _themeController.themeMode,
            routeInformationProvider: _router.routeInformationProvider,
            routeInformationParser: _router.routeInformationParser,
            routerDelegate: _router.routerDelegate,
            backButtonDispatcher: _backButtonDispatcher,
          );
        },
      ),
    );
  }
}

class _SellerBackButtonDispatcher extends RootBackButtonDispatcher {
  _SellerBackButtonDispatcher(this._router, this._scaffoldMessengerKey);

  static const Duration _exitConfirmDuration = Duration(seconds: 2);

  static const Set<String> _rootTabLocations = {
    SellerRoutes.dashboard,
    SellerRoutes.operations,
    SellerRoutes.orders,
    SellerRoutes.customers,
    SellerRoutes.my,
  };

  final GoRouter _router;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;

  DateTime? _lastBackPressedAt;

  @override
  Future<bool> invokeCallback(Future<bool> defaultValue) async {
    final handledByRouter = await super.invokeCallback(defaultValue);

    if (handledByRouter) {
      _lastBackPressedAt = null;

      return true;
    }

    final location = _normalizeLocation(
      _router.routeInformationProvider.value.uri.path,
    );

    if (!_rootTabLocations.contains(location)) {
      _lastBackPressedAt = null;

      return false;
    }

    if (location != SellerRoutes.dashboard) {
      _lastBackPressedAt = null;

      _router.go(SellerRoutes.dashboard);

      return true;
    }

    final now = DateTime.now();

    final previousPressedAt = _lastBackPressedAt;

    final shouldExit =
        previousPressedAt != null &&
        now.difference(previousPressedAt) <= _exitConfirmDuration;

    if (shouldExit) {
      _lastBackPressedAt = null;

      await SystemNavigator.pop();

      return true;
    }

    _lastBackPressedAt = now;

    final messenger = _scaffoldMessengerKey.currentState;

    messenger
      ?..hideCurrentTopSnackBar()
      ..showTopSnackBar(
        const SnackBar(
          content: Text('??踰????꾨Ⅴ硫??깆씠 醫낅즺?⑸땲??'),
          duration: _exitConfirmDuration,
        ),
      );

    return true;
  }

  String _normalizeLocation(String location) {
    if (location.length > 1 && location.endsWith('/')) {
      return location.substring(0, location.length - 1);
    }

    return location;
  }
}

