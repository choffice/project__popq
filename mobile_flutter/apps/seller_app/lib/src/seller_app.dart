import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'features/orders/seller_order_repository.dart';
import 'features/products/seller_product_repository.dart';
import 'features/stores/seller_store_repository.dart';
import 'features/stores/seller_store_selection_controller.dart';
import 'features/stores/seller_store_selection_store.dart';
import 'notifications/seller_push_device_repository.dart';
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
  final PopqThemeController? themeController;
  final SellerAuthRepository? authRepository;

  /// 스플래시 화면(부트스트랩)을 최소 이 시간만큼 보여줍니다.
  ///
  /// 위젯 테스트에서는 [Duration.zero]로 넘겨서 스플래시를 건너뛸 수 있습니다.
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    final useMemoryStorage =
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

    _googleAuthService = GoogleAuthService(
      webClientId:
          '977349461588-b8tqabapb8k86gkok0qd6lem7jjd5r8i.apps.googleusercontent.com',
    );

    _kakaoAuthService = KakaoAuthService();

    _naverAuthService = NaverAuthService();

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

    final identityRepository =
        widget.identityRepository ?? ApiSellerIdentityRepository(_apiClient);

    _authRepository =
        widget.authRepository ?? ApiSellerAuthRepository(_apiClient);

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
      customerRepository: _customerRepository,
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
      '판매자 Google 로그인 성공: ID Token 수신 '
      '(${idToken.length}자)',
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
      '판매자 Kakao 로그인 성공: Access Token 수신 '
      '(${accessToken.length}자)',
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
      '판매자 Naver 로그인 성공: Access Token 수신 '
      '(${accessToken.length}자)',
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
        'name': 'POPQ 지도 테스트 판매자',
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

  void _handleSessionChanged() {
    if (_sessionController.status == SessionStatus.restoring) {
      return;
    }

    if (!_sessionController.isSignedIn) {
      _realtimeClient.disconnect(clearSubscriptions: true);
      return;
    }

    unawaited(_registerPushDevice());

    if (_isAppActive) {
      unawaited(_realtimeClient.connect());
    }
  }

  Future<void> _registerPushDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint(
          'Seller 알림 권한이 없어 '
          'FCM 기기를 등록하지 않습니다.',
        );
        return;
      }

      final token = await messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint(
          'Seller FCM 토큰이 없어 '
          '기기를 등록하지 않습니다.',
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
        'Seller FCM 기기 등록 완료: '
        'deviceId=${device.deviceId}, '
        'platform=${device.platform}',
      );
    } catch (error, stackTrace) {
      debugPrint('Seller FCM 기기 등록 실패: $error');
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
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('한 번 더 누르면 앱이 종료됩니다.'),
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
