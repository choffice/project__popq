import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'features/auth/customer_auth_repository.dart';
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
    this.cartController,
    this.permissionGateway,
    this.locationRepository,
    this.themeController,
    this.authRepository,
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
  final CartController? cartController;
  final CustomerPermissionGateway? permissionGateway;
  final CustomerLocationRepository? locationRepository;
  final PopqThemeController? themeController;
  final CustomerAuthRepository? authRepository;

  /// 스플래시 화면(부트스트랩)을 최소 이 시간만큼 보여줍니다.
  ///
  /// 위젯 테스트에서는 [Duration.zero]로 넘겨서 스플래시를 건너뛸 수 있습니다.
  final Duration splashMinDuration;

  @override
  State<PopqCustomerApp> createState() =>
      _PopqCustomerAppState();
}

class _PopqCustomerAppState extends State<PopqCustomerApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();

  late final SessionController _sessionController;
  late final OnboardingController _onboardingController;
  late final SessionStore _sessionStore;
  late final PopqApiClient _apiClient;
  late final CartController _cartController;
  late final CustomerHomeController _homeController;
  late final PopqThemeController _themeController;
  late final bool _ownsThemeController;
  late final GoRouter _router;
  late final GoogleAuthService _googleAuthService;
  late final CustomerAuthRepository _authRepository;
  late final _CustomerBackButtonDispatcher _backButtonDispatcher;
  late final KakaoAuthService _kakaoAuthService;
  late final NaverAuthService _naverAuthService;

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

    _googleAuthService = GoogleAuthService(
      webClientId:
      '977349461588-b8tqabapb8k86gkok0qd6lem7jjd5r8i.apps.googleusercontent.com',
    );

    _authRepository =
        widget.authRepository ??
            ApiCustomerAuthRepository(
              _apiClient,
            );

    _kakaoAuthService = KakaoAuthService();
    _naverAuthService = NaverAuthService();

    final permissionGateway =
        widget.permissionGateway ??
            DeviceCustomerPermissionGateway();

    final locationRepository =
        widget.locationRepository ??
            ApiCustomerLocationRepository(
              _apiClient,
            );

    final storeDiscoveryRepository =
        widget.storeDiscoveryRepository ??
            ApiStoreDiscoveryRepository(
              _apiClient,
            );

    final catalogRepository =
        widget.catalogRepository ??
            ApiCatalogRepository(
              _apiClient,
            );

    final orderRepository =
        widget.orderRepository ??
            ApiCustomerOrderRepository(
              _apiClient,
            );

    final orderMessageRepository =
        widget.orderMessageRepository ??
            ApiCustomerOrderMessageRepository(
              _apiClient,
            );

    final engagementRepository =
        widget.engagementRepository ??
            ApiCustomerEngagementRepository(
              _apiClient,
            );

    final notificationRepository =
        widget.notificationRepository ??
            ApiCustomerNotificationRepository(
              _apiClient,
            );

    _cartController =
        widget.cartController ??
            CartController();

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
      onVerifyForPasswordReset:
      _verifyForPasswordReset,
      onResetPassword:
      _resetPassword,
      sessionController:
      _sessionController,
      onboardingController:
      _onboardingController,
      storeDiscoveryRepository:
      storeDiscoveryRepository,
      catalogRepository:
      catalogRepository,
      orderRepository:
      orderRepository,
      orderMessageRepository:
      orderMessageRepository,
      engagementRepository:
      engagementRepository,
      notificationRepository:
      notificationRepository,
      cartController:
      _cartController,
      homeController:
      _homeController,
      minSplashDuration:
      widget.splashMinDuration,
      permissionGateway:
      permissionGateway,
      locationRepository:
      locationRepository,
      tossClientKey:
      widget.environment.tossClientKey,
      themeController:
      _themeController,
      onDevelopmentSignIn:
      widget.environment.flavor ==
          AppFlavor.development
          ? _developmentSignIn
          : null,
      onGoogleSignIn:
      _googleSignIn,
      onKakaoSignIn:
      _kakaoSignIn,
      onNaverSignIn:
      _naverSignIn,
    );

    _backButtonDispatcher =
        _CustomerBackButtonDispatcher(
          router: _router,
          scaffoldMessengerKey:
          _scaffoldMessengerKey,
        );

    unawaited(
      Future.wait([
        _sessionController.restore(),
        _onboardingController.restore(),
        _themeController.restore(),
      ]).then((_) => _homeController.load()),
    );
  }

  Future<void> _developmentSignIn() async {
    final response =
    await _apiClient.post<
        Map<String, Object?>>(
      '/api/v1/dev/auth/login',
      body: {
        'email':
        'customer-app-dev@popq.local',
        'name':
        'POPQ 개발 고객',
        'role':
        'CUSTOMER',
      },
      decode: (value) {
        return Map<String, Object?>.from(
          value as Map,
        );
      },
    );

    final expiresIn =
    (response['expiresIn'] as num)
        .toInt();

    await _sessionController.save(
      AuthSession(
        accessToken:
        response['accessToken']
        as String,
        refreshToken: '',
        expiresAt: DateTime.now()
            .toUtc()
            .add(
          Duration(
            seconds: expiresIn,
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(
      String email,
      String password,
      ) async {
    final session =
    await _authRepository.logIn(
      email: email,
      password: password,
    );

    await _sessionController.save(
      session,
    );
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

  Future<String> _findId(
      String name,
      String phone,
      ) {
    return _authRepository.findId(
      name: name,
      phone: phone,
    );
  }

  Future<void> _verifyForPasswordReset(
      String email,
      String phone,
      ) {
    return _authRepository
        .verifyForPasswordReset(
      email: email,
      phone: phone,
    );
  }

  Future<void> _resetPassword(
      String email,
      String phone,
      String newPassword,
      ) {
    return _authRepository.resetPassword(
      email: email,
      phone: phone,
      newPassword: newPassword,
    );
  }

  Future<void> _googleSignIn() async {
    final idToken =
    await _googleAuthService
        .signInAndGetIdToken();

    debugPrint(
      'Google idToken: $idToken',
    );

    // TODO(backend): Spring Security 엔드포인트 확정되면
    // idToken을 body에 담아 POST 요청 → 응답의 accessToken/refreshToken을
    // _sessionController.save(AuthSession(...))에 저장하는 코드로 교체
  }

  Future<void> _kakaoSignIn() async {
    final accessToken =
    await _kakaoAuthService
        .signInAndGetAccessToken();

    debugPrint(
      '카카오 로그인 성공: Access Token 수신 '
          '(${accessToken.length}자)',
    );

    // TODO(backend): 카카오 Access Token을 Spring 로그인 API로 전송하고,
    // 응답으로 받은 POPQ accessToken/refreshToken을 AuthSession에 저장합니다.
  }

  Future<void> _naverSignIn() async {
    final accessToken =
    await _naverAuthService
        .signInAndGetAccessToken();

    debugPrint(
      '네이버 로그인 성공: Access Token 수신 '
          '(${accessToken.length}자)',
    );

    // TODO(backend): 네이버 Access Token을 Spring 로그인 API로 전송하고,
    // 응답으로 받은 POPQ accessToken/refreshToken을 AuthSession에 저장합니다.
  }

  @override
  void dispose() {
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
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'POPQ',
          debugShowCheckedModeBanner:
          !widget.environment.isProduction,
          scaffoldMessengerKey:
          _scaffoldMessengerKey,
          theme:
          PopqTheme.light(),
          darkTheme:
          PopqTheme.dark(),
          themeMode:
          _themeController.themeMode,

          /*
           * routerConfig를 그대로 넘기지 않고
           * Router 구성 요소를 각각 전달합니다.
           *
           * 이렇게 해야 최상위 Android 뒤로가기를 처리할
           * BackButtonDispatcher를 직접 지정할 수 있습니다.
           */
          routeInformationProvider:
          _router
              .routeInformationProvider,
          routeInformationParser:
          _router
              .routeInformationParser,
          routerDelegate:
          _router.routerDelegate,
          backButtonDispatcher:
          _backButtonDispatcher,
        );
      },
    );
  }
}

class _CustomerBackButtonDispatcher
    extends RootBackButtonDispatcher {
  _CustomerBackButtonDispatcher({
    required GoRouter router,
    required GlobalKey<ScaffoldMessengerState>
    scaffoldMessengerKey,
  })  : _router = router,
        _scaffoldMessengerKey =
            scaffoldMessengerKey;

  static const Duration
  _exitConfirmDuration =
  Duration(seconds: 2);

  static const Set<String>
  _rootTabLocations = {
    CustomerRoutes.home,
    CustomerRoutes.discover,
    CustomerRoutes.qrScanner,
    CustomerRoutes.favorites,
    CustomerRoutes.profile,
  };

  final GoRouter _router;

  final GlobalKey<ScaffoldMessengerState>
  _scaffoldMessengerKey;

  DateTime? _lastBackPressedAt;

  @override
  Future<bool> invokeCallback(
      Future<bool> defaultValue,
      ) async {
    /*
     * 주문 상세, 매장 상세, 장바구니, 결제 등의 화면에서는
     * 기존 Navigator와 PopScope가 먼저 뒤로가기를 처리합니다.
     */
    final handledByRouter =
    await super.invokeCallback(
      defaultValue,
    );

    if (handledByRouter) {
      _lastBackPressedAt = null;
      return true;
    }

    final location =
    _normalizeLocation(
      _router
          .routeInformationProvider
          .value
          .uri
          .path,
    );

    /*
     * 하단 탭 루트가 아닌 화면에서 기존 라우터가
     * 처리하지 못했다면 Android 기본 동작을 허용합니다.
     */
    if (!_rootTabLocations.contains(
      location,
    )) {
      _lastBackPressedAt = null;
      return false;
    }

    /*
     * 홈이 아닌 하단 탭에서는 앱을 종료하지 않고
     * 홈으로 이동합니다.
     */
    if (location !=
        CustomerRoutes.home) {
      _lastBackPressedAt = null;

      _router.go(
        CustomerRoutes.home,
      );

      return true;
    }

    final now = DateTime.now();

    final previousPressedAt =
        _lastBackPressedAt;

    final shouldExit =
        previousPressedAt != null &&
            now.difference(
              previousPressedAt,
            ) <=
                _exitConfirmDuration;

    /*
     * 홈에서 2초 이내에 두 번째로 누른 경우에만 종료합니다.
     */
    if (shouldExit) {
      _lastBackPressedAt = null;

      await SystemNavigator.pop();

      return true;
    }

    /*
     * 홈에서 첫 번째로 누른 경우입니다.
     */
    _lastBackPressedAt = now;

    final messenger =
        _scaffoldMessengerKey
            .currentState;

    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            '한 번 더 누르면 앱이 종료됩니다.',
          ),
          duration:
          _exitConfirmDuration,
        ),
      );

    return true;
  }

  String _normalizeLocation(
      String location,
      ) {
    if (location.length > 1 &&
        location.endsWith('/')) {
      return location.substring(
        0,
        location.length - 1,
      );
    }

    return location;
  }
}