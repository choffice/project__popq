import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/auth/customer_auth_repository.dart';
import 'features/auth/customer_identity_repository.dart';
import 'features/auth/kakao_auth_service.dart';
import 'features/auth/naver_auth_service.dart';
import 'features/cart/cart_controller.dart';
import 'features/catalog/catalog_repository.dart';
import 'features/discovery/store_discovery_repository.dart';
import 'features/home/customer_home_controller.dart';
import 'features/home/customer_location_repository.dart';
import 'features/inquiry/customer_order_message_repository.dart';
import 'features/notifications/customer_notification_repository.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/onboarding/onboarding_store.dart';
import 'features/orders/customer_order_repository.dart';
import 'features/permissions/customer_permission_gateway.dart';
import 'features/profile/customer_engagement_repository.dart';
import 'realtime/customer_realtime_scope.dart';
import 'routing/customer_router.dart';

class PopqCustomerApp extends StatefulWidget {
  const PopqCustomerApp({
    required this.environment,
    this.sessionStore,
    this.onboardingStore,
    this.storeDiscoveryRepository,
    this.catalogRepository,
    this.orderRepository,
    this.orderMessageRepository,
    this.engagementRepository,
    this.notificationRepository,
    this.locationRepository,
    this.cartController,
    this.permissionGateway,
    this.themeController,
    this.authRepository,
    this.identityRepository,
    this.splashMinDuration = const Duration(seconds: 3),
    super.key,
  });

  final AppEnvironment environment;
  final SessionStore? sessionStore;
  final OnboardingStore? onboardingStore;
  final StoreDiscoveryRepository? storeDiscoveryRepository;
  final CatalogRepository? catalogRepository;
  final CustomerOrderRepository? orderRepository;
  final CustomerOrderMessageRepository? orderMessageRepository;
  final CustomerEngagementRepository? engagementRepository;
  final CustomerNotificationRepository? notificationRepository;
  final CustomerLocationRepository? locationRepository;
  final CartController? cartController;
  final CustomerPermissionGateway? permissionGateway;
  final PopqThemeController? themeController;
  final CustomerAuthRepository? authRepository;
  final CustomerIdentityRepository? identityRepository;

  /// 스플래시 화면(부트스트랩)을 최소 이 시간만큼 보여줍니다.
  ///
  /// 위젯 테스트에서는 [Duration.zero]로 넘겨서 스플래시를 건너뛸 수 있습니다.
  final Duration splashMinDuration;

  @override
  State<PopqCustomerApp> createState() {
    return _PopqCustomerAppState();
  }
}

class _PopqCustomerAppState extends State<PopqCustomerApp>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final SessionController _sessionController;
  late final OnboardingController _onboardingController;
  late final SessionStore _sessionStore;
  late final PopqApiClient _apiClient;
  late final CustomerNotificationRepository _notificationRepository;
  late final PopqRealtimeClient _realtimeClient;
  late final CartController _cartController;
  late final CustomerHomeController _homeController;
  late final PopqThemeController _themeController;
  late final bool _ownsThemeController;
  late final GoRouter _router;
  late final GoogleAuthService _googleAuthService;
  late final CustomerAuthRepository _authRepository;
  late final CustomerIdentityRepository _identityRepository;
  late final _CustomerBackButtonDispatcher _backButtonDispatcher;
  late final KakaoAuthService _kakaoAuthService;
  late final NaverAuthService _naverAuthService;

  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _isAppActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    _sessionStore = widget.sessionStore ?? SecureSessionStore();

    _sessionController = SessionController(sessionStore: _sessionStore);

    _onboardingController = OnboardingController(
      widget.onboardingStore ?? SharedPreferencesOnboardingStore(),
    );

    _ownsThemeController = widget.themeController == null;

    _themeController = widget.themeController ?? PopqThemeController();

    _apiClient = PopqApiClient(
      baseUrl: widget.environment.apiBaseUrl,
      accessTokenReader: () async {
        return (await _sessionStore.read())?.accessToken;
      },
    );

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

    _authRepository =
        widget.authRepository ?? ApiCustomerAuthRepository(_apiClient);

    _identityRepository =
        widget.identityRepository ?? ApiCustomerIdentityRepository(_apiClient);

    _kakaoAuthService = KakaoAuthService();
    _naverAuthService = NaverAuthService();

    final permissionGateway =
        widget.permissionGateway ?? DeviceCustomerPermissionGateway();

    final storeDiscoveryRepository =
        widget.storeDiscoveryRepository ??
        ApiStoreDiscoveryRepository(
          _apiClient,
          imageBaseUrl: widget.environment.apiBaseUrl,
        );

    final catalogRepository =
        widget.catalogRepository ?? ApiCatalogRepository(_apiClient);

    final orderRepository =
        widget.orderRepository ?? ApiCustomerOrderRepository(_apiClient);

    final orderMessageRepository =
        widget.orderMessageRepository ??
        ApiCustomerOrderMessageRepository(_apiClient);

    final engagementRepository =
        widget.engagementRepository ??
        ApiCustomerEngagementRepository(
          _apiClient,
          imageBaseUrl: widget.environment.apiBaseUrl,
        );

    _notificationRepository =
        widget.notificationRepository ??
        ApiCustomerNotificationRepository(_apiClient);

    final locationRepository =
        widget.locationRepository ?? ApiCustomerLocationRepository(_apiClient);

    _cartController = widget.cartController ?? CartController();

    _homeController = CustomerHomeController(
      storeDiscoveryRepository,
      orderRepository,
      _sessionController,
      permissionGateway,
      locationRepository,
    );

    _router = createCustomerRouter(
      onSignIn: _signIn,
      onSignUp: _signUp,
      onFindId: _findId,
      onVerifyForPasswordReset: _verifyForPasswordReset,
      onResetPassword: _resetPassword,
      onConnectSellerAccess: _connectSellerAccess,
      onWithdraw: _withdraw,
      sessionController: _sessionController,
      onboardingController: _onboardingController,
      storeDiscoveryRepository: storeDiscoveryRepository,
      catalogRepository: catalogRepository,
      orderRepository: orderRepository,
      orderMessageRepository: orderMessageRepository,
      engagementRepository: engagementRepository,
      notificationRepository: _notificationRepository,
      locationRepository: locationRepository,
      cartController: _cartController,
      homeController: _homeController,
      minSplashDuration: widget.splashMinDuration,
      permissionGateway: permissionGateway,
      apiBaseUrl: widget.environment.apiBaseUrl,
      tossClientKey: widget.environment.tossClientKey,
      themeController: _themeController,
      onDevelopmentSignIn: widget.environment.flavor == AppFlavor.development
          ? _developmentSignIn
          : null,
      onGoogleSignIn: _googleSignIn,
      onKakaoSignIn: _kakaoSignIn,
      onNaverSignIn: _naverSignIn,
    );

    _backButtonDispatcher = _CustomerBackButtonDispatcher(
      router: _router,
      scaffoldMessengerKey: _scaffoldMessengerKey,
    );

    unawaited(
      Future.wait([
        _sessionController.restore().then((_) => _verifyCustomerSession()),
        _onboardingController.restore(),
        _themeController.restore(),
      ]).then((_) => _homeController.load()),
    );
  }

  Future<void> _verifyCustomerSession() async {
    if (!_sessionController.isSignedIn) return;

    try {
      final identity = await _identityRepository.getCurrent();
      if (!identity.isCustomer) {
        await _sessionController.signOut();
      }
    } on AuthenticationFailure {
      await _sessionController.signOut();
    } catch (_) {
      // 일시적인 네트워크 오류 등은 세션을 로그아웃시키지 않고 그대로 둡니다.
    }
  }

  Future<void> _developmentSignIn() async {
    final response = await _apiClient.post<Map<String, Object?>>(
      '/api/v1/dev/auth/login',
      body: {
        'email': 'customer-app-dev@popq.local',
        'name': 'POPQ 개발 고객',
        'role': 'CUSTOMER',
      },
      decode: (value) {
        return Map<String, Object?>.from(value as Map);
      },
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

  Future<void> _signIn(String email, String password) async {
    final session = await _authRepository.logIn(
      email: email,
      password: password,
    );

    await _sessionController.save(session);
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

  Future<void> _connectSellerAccess() {
    return _authRepository.connectSellerAccess();
  }

  Future<void> _withdraw(String? confirmationPhrase) async {
    await _authRepository.withdraw(confirmationPhrase: confirmationPhrase);
    await _sessionController.signOut();
  }

  Future<void> _googleSignIn() async {
    final idToken = await _googleAuthService.signInAndGetIdToken();

    debugPrint('Google idToken: $idToken');

    final session = await _authRepository.socialLogIn(
      provider: 'GOOGLE',
      providerToken: idToken,
    );

    await _sessionController.save(session);
  }

  Future<void> _kakaoSignIn() async {
    final accessToken = await _kakaoAuthService.signInAndGetAccessToken();

    debugPrint(
      '카카오 로그인 성공: Access Token 수신 '
      '(${accessToken.length}자)',
    );

    final session = await _authRepository.socialLogIn(
      provider: 'KAKAO',
      providerToken: accessToken,
    );

    await _sessionController.save(session);
  }

  Future<void> _naverSignIn() async {
    final accessToken = await _naverAuthService.signInAndGetAccessToken();

    debugPrint(
      '네이버 로그인 성공: Access Token 수신 '
      '(${accessToken.length}자)',
    );

    final session = await _authRepository.socialLogIn(
      provider: 'NAVER',
      providerToken: accessToken,
    );

    await _sessionController.save(session);
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
          'Customer 알림 권한이 없어 '
          'FCM 기기를 등록하지 않습니다.',
        );
        return;
      }

      final token = await messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint(
          'Customer FCM 토큰이 없어 '
          '기기를 등록하지 않습니다.',
        );
        return;
      }

      final platform = switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'IOS',
        _ => 'ANDROID',
      };

      final device = await _notificationRepository.registerDevice(
        token: token.trim(),
        platform: platform,
      );

      debugPrint(
        'Customer FCM 기기 등록 완료: '
        'deviceId=${device.deviceId}, '
        'platform=${device.platform}',
      );
    } catch (error, stackTrace) {
      debugPrint('Customer FCM 기기 등록 실패: $error');
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
    _cartController.dispose();
    _homeController.dispose();
    _onboardingController.dispose();
    _sessionController.dispose();

    if (_ownsThemeController) {
      _themeController.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerRealtimeScope(
      client: _realtimeClient,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, child) {
          return MaterialApp.router(
            title: 'POPQ',
            debugShowCheckedModeBanner: !widget.environment.isProduction,
            scaffoldMessengerKey: _scaffoldMessengerKey,
            theme: PopqTheme.light(),
            darkTheme: PopqTheme.dark(),
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

class _CustomerBackButtonDispatcher extends RootBackButtonDispatcher {
  _CustomerBackButtonDispatcher({
    required GoRouter router,
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
  }) : _router = router,
       _scaffoldMessengerKey = scaffoldMessengerKey;

  static const Duration _exitConfirmDuration = Duration(seconds: 2);

  static const Set<String> _rootTabLocations = {
    CustomerRoutes.home,
    CustomerRoutes.discover,
    CustomerRoutes.qrScanner,
    CustomerRoutes.favorites,
    CustomerRoutes.profile,
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

    if (location != CustomerRoutes.home) {
      _lastBackPressedAt = null;

      _router.go(CustomerRoutes.home);

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
