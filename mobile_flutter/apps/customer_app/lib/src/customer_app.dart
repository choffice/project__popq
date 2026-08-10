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
import 'features/orders/pending_payment_recovery_service.dart';
import 'features/permissions/customer_permission_gateway.dart';
import 'features/profile/customer_engagement_repository.dart';
import 'notifications/customer_push_notification_service.dart';
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

  /// ?ㅽ뵆?섏떆 ?붾㈃(遺?몄뒪?몃옪)??理쒖냼 ???쒓컙留뚰겮 蹂댁뿬以띾땲??
  ///
  /// ?꾩젽 ?뚯뒪?몄뿉?쒕뒗 [Duration.zero]濡??섍꺼???ㅽ뵆?섏떆瑜?嫄대꼫?????덉뒿?덈떎.
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
  late final CustomerOrderRepository _orderRepository;
  late final PendingPaymentRecoveryService _pendingPaymentRecoveryService;
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

  final DateTime _appStartedAt = DateTime.now();

  bool _isAppActive = true;
  bool _isRecoveringPendingPayment = false;
  String? _pendingPushDeepLink;
  String? _lastPaymentRecoveryNotice;

  //?ㅼ갹 : ??媛쒕컻紐⑤뱶 ?꾩슜
  bool get _isWebDevelopment =>
      kIsWeb &&
          widget.environment.flavor == AppFlavor.development;
  Future<void> Function()? get _webSafeGoogleSignIn =>
      _isWebDevelopment ? null : _googleSignIn;

  Future<void> Function()? get _webSafeKakaoSignIn =>
      _isWebDevelopment ? null : _kakaoSignIn;

  Future<void> Function()? get _webSafeNaverSignIn =>
      _isWebDevelopment ? null : _naverSignIn;

  Future<void> Function()? get _webSafeGoogleLink =>
      _isWebDevelopment ? null : _googleLink;

  Future<void> Function()? get _webSafeKakaoLink =>
      _isWebDevelopment ? null : _kakaoLink;

  Future<void> Function()? get _webSafeNaverLink =>
      _isWebDevelopment ? null : _naverLink;
  //?ш린源뚯? ?ㅼ갹


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

    //?ㅼ갹
    if (!_isWebDevelopment) {
      _googleAuthService = GoogleAuthService(
        webClientId:
          '977349461588-b8tqabapb8k86gkok0qd6lem7jjd5r8i.apps.googleusercontent.com',
      );

      _kakaoAuthService = KakaoAuthService();
      _naverAuthService = NaverAuthService();
    }

    _authRepository =
        widget.authRepository ?? ApiCustomerAuthRepository(_apiClient);

    _identityRepository =
        widget.identityRepository ?? ApiCustomerIdentityRepository(_apiClient);

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

    _orderRepository =
        widget.orderRepository ?? ApiCustomerOrderRepository(_apiClient);

    _pendingPaymentRecoveryService = PendingPaymentRecoveryService(
      repository: _orderRepository,
    );

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
      _orderRepository,
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
      orderRepository: _orderRepository,
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
      // onGoogleSignIn: _googleSignIn,
      // onKakaoSignIn: _kakaoSignIn,
      // onNaverSignIn: _naverSignIn,
      // onGoogleLink: _googleLink,
      // onKakaoLink: _kakaoLink,
      // onNaverLink: _naverLink,
      onGoogleSignIn: _webSafeGoogleSignIn,
      onKakaoSignIn: _webSafeKakaoSignIn,
      onNaverSignIn: _webSafeNaverSignIn,
      onGoogleLink: _webSafeGoogleLink,
      onKakaoLink: _webSafeKakaoLink,
      onNaverLink: _webSafeNaverLink,
    );

    PushNotificationService.setDeepLinkHandler(_handlePushDeepLink);

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
      // ?쇱떆?곸씤 ?ㅽ듃?뚰겕 ?ㅻ쪟 ?깆? ?몄뀡??濡쒓렇?꾩썐?쒗궎吏 ?딄퀬 洹몃?濡??〓땲??
    }
  }

  Future<void> _developmentSignIn() async {
    final response = await _apiClient.post<Map<String, Object?>>(
      '/api/v1/dev/auth/login',
      body: {
        'email': 'customer-app-dev@popq.local',
        'name': 'POPQ 媛쒕컻 怨좉컼',
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
      '移댁뭅??濡쒓렇???깃났: Access Token ?섏떊 '
      '(${accessToken.length}??',
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
      '?ㅼ씠踰?濡쒓렇???깃났: Access Token ?섏떊 '
      '(${accessToken.length}??',
    );

    final session = await _authRepository.socialLogIn(
      provider: 'NAVER',
      providerToken: accessToken,
    );

    await _sessionController.save(session);
  }

  Future<void> _googleLink() async {
    final idToken = await _googleAuthService.signInAndGetIdToken();

    await _authRepository.linkSocialAccount(
      provider: 'GOOGLE',
      providerToken: idToken,
    );
  }

  Future<void> _kakaoLink() async {
    final accessToken = await _kakaoAuthService.signInAndGetAccessToken();

    await _authRepository.linkSocialAccount(
      provider: 'KAKAO',
      providerToken: accessToken,
    );
  }

  Future<void> _naverLink() async {
    final accessToken = await _naverAuthService.signInAndGetAccessToken();

    await _authRepository.linkSocialAccount(
      provider: 'NAVER',
      providerToken: accessToken,
    );
  }

  void _handlePushDeepLink(String deepLink) {
    if (!_isSupportedCustomerDeepLink(deepLink)) {
      debugPrint('Customer 吏?먰븯吏 ?딅뒗 ?뚮┝ 寃쎈줈: $deepLink');
      return;
    }

    if (!_sessionController.isSignedIn) {
      _pendingPushDeepLink = deepLink;
      return;
    }

    _openPushDeepLink(deepLink);
  }

  bool _isSupportedCustomerDeepLink(String deepLink) {
    final uri = Uri.tryParse(deepLink);
    if (uri == null) {
      return false;
    }
    final segments = uri.pathSegments;
    final isOrderDetail =
        segments.length == 2 &&
        segments.first == 'orders' &&
        segments[1].isNotEmpty;
    final isOrderChat =
        segments.length == 3 &&
        segments.first == 'orders' &&
        segments[1].isNotEmpty &&
        segments[2] == 'messages';
    final isStoreDetail =
        segments.length == 2 &&
        segments.first == 'stores' &&
        int.tryParse(segments[1]) != null;

    return isOrderDetail || isOrderChat || isStoreDetail;
  }

  void _openPushDeepLink(String deepLink) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _router.go(deepLink);
    });
  }

  void _handleSessionChanged() {
    if (_sessionController.status == SessionStatus.restoring) {
      return;
    }

    if (!_sessionController.isSignedIn) {
      _realtimeClient.disconnect(clearSubscriptions: true);
      return;
    }

    //?ㅼ갹
    if (!_isWebDevelopment) {
      unawaited(_registerPushDevice());
    }

    final pendingPushDeepLink = _pendingPushDeepLink;

    if (pendingPushDeepLink != null) {
      _pendingPushDeepLink = null;
      _openPushDeepLink(pendingPushDeepLink);
    }

    unawaited(
      _recoverPendingPaymentIfNeeded(
        navigateWhenPaid: pendingPushDeepLink == null,
      ),
    );

    if (_isAppActive) {
      unawaited(_realtimeClient.connect());
    }
  }

  Future<void> _recoverPendingPaymentIfNeeded({
    bool navigateWhenPaid = true,
  }) async {
    if (_isRecoveringPendingPayment || !_sessionController.isSignedIn) {
      return;
    }

    _isRecoveringPendingPayment = true;

    try {
      final outcome = await _pendingPaymentRecoveryService.recover();

      if (!mounted || !_sessionController.isSignedIn) {
        return;
      }

      switch (outcome.kind) {
        case PendingPaymentRecoveryKind.none:
          return;

        case PendingPaymentRecoveryKind.paid:
          _cartController.clear();

          _showPaymentRecoveryNotice(outcome.message ?? '寃곗젣媛 ?뺤긽?곸쑝濡??뺤씤?섏뿀?듬땲??');

          final orderPublicId = outcome.orderPublicId;

          if (navigateWhenPaid &&
              orderPublicId != null &&
              orderPublicId.isNotEmpty) {
            unawaited(_openRecoveredOrderAfterBootstrap(orderPublicId));
          }

          return;

        case PendingPaymentRecoveryKind.retryAllowed:
          _showPaymentRecoveryNotice(
            outcome.message ??
                '?댁쟾 寃곗젣???꾨즺?섏? ?딆븯?듬땲?? '
                    '?ㅼ떆 寃곗젣?????덉뒿?덈떎.',
          );
          return;

        case PendingPaymentRecoveryKind.pending:
          _showPaymentRecoveryNotice(
            outcome.message ??
                '寃곗젣 寃곌낵瑜??뺤씤?섍퀬 ?덉뒿?덈떎. '
                    '?좎떆 ???먮룞?쇰줈 ?ㅼ떆 ?뺤씤?⑸땲??',
          );
          return;

        case PendingPaymentRecoveryKind.manualReview:
        case PendingPaymentRecoveryKind.inconsistent:
          _showPaymentRecoveryNotice(
            outcome.message ??
                '寃곗젣 ?곹깭瑜??먮룞?쇰줈 ?뺤젙?????놁뒿?덈떎. '
                    '二쇰Ц쨌寃곗젣 ?댁뿭???뺤씤?댁＜?몄슂.',
          );
          return;

        case PendingPaymentRecoveryKind.unavailable:
          _showPaymentRecoveryNotice(
            outcome.message ??
                '寃곗젣 ?곹깭瑜??뺤씤?섏? 紐삵뻽?듬땲?? '
                    '?ㅽ듃?뚰겕 ?곌껐 ???ㅼ떆 ?뺤씤?⑸땲??',
          );
          return;
      }
    } catch (error, stackTrace) {
      debugPrint('Customer pending 寃곗젣 ?먮룞 蹂듦뎄 ?ㅽ뙣: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isRecoveringPendingPayment = false;
    }
  }

  Future<void> _openRecoveredOrderAfterBootstrap(String orderPublicId) async {
    final elapsed = DateTime.now().difference(_appStartedAt);

    final remaining = widget.splashMinDuration - elapsed;

    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    if (!mounted || !_sessionController.isSignedIn) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sessionController.isSignedIn) {
        return;
      }

      _router.go('${CustomerRoutes.orders}/$orderPublicId');
    });
  }

  void _showPaymentRecoveryNotice(String message) {
    if (message.trim().isEmpty || _lastPaymentRecoveryNotice == message) {
      return;
    }

    _lastPaymentRecoveryNotice = message;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final messenger = _scaffoldMessengerKey.currentState;

      messenger?.hideCurrentTopSnackBar();
      messenger?.showTopSnackBar(SnackBar(content: Text(message)));
    });
  }

  Future<void> _registerPushDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        debugPrint(
          'Customer ?뚮┝ 沅뚰븳???놁뼱 '
          'FCM 湲곌린瑜??깅줉?섏? ?딆뒿?덈떎.',
        );
        return;
      }

      final token = await messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint(
          'Customer FCM ?좏겙???놁뼱 '
          '湲곌린瑜??깅줉?섏? ?딆뒿?덈떎.',
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
        'Customer FCM 湲곌린 ?깅줉 ?꾨즺: '
        'deviceId=${device.deviceId}, '
        'platform=${device.platform}',
      );
    } catch (error, stackTrace) {
      debugPrint('Customer FCM 湲곌린 ?깅줉 ?ㅽ뙣: $error');
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
          unawaited(_recoverPendingPaymentIfNeeded());
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
    PushNotificationService.clearDeepLinkHandler();
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

