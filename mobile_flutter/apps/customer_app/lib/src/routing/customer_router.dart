import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../customer_root_screen.dart';
import '../features/auth/customer_find_id_screen.dart';
import '../features/auth/customer_find_password_screen.dart';
import '../features/auth/customer_sign_up_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/cart/cart_controller.dart';
import '../features/cart/cart_screen.dart';
import '../features/catalog/catalog_repository.dart';
import '../features/announcements/public_announcement_repository.dart';
import '../features/announcements/public_announcement_screens.dart';
import '../features/catalog/product_detail_screen.dart';
import '../features/catalog/product_list_screen.dart';
import '../features/discovery/store_detail_screen.dart';
import '../features/discovery/store_discovery_repository.dart';
import '../features/discovery/store_discovery_screen.dart';
import '../features/discovery/store_review_screen.dart';
import '../features/favorites/customer_favorite_store_screen.dart';
import '../features/home/customer_home_controller.dart';
import '../features/home/customer_home_screen.dart';
import '../features/home/customer_location_repository.dart';
import '../features/inquiry/customer_order_chat_screen.dart';
import '../features/inquiry/customer_order_message_repository.dart';
import '../features/notifications/customer_notification_repository.dart';
import '../features/notifications/notification_list_screen.dart';
import '../features/onboarding/onboarding_controller.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/orders/checkout_screen.dart';
import '../features/orders/customer_order_repository.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_list_screen.dart';
import '../features/permissions/customer_permission_gateway.dart';
import '../features/profile/customer_engagement_repository.dart';
import '../features/profile/customer_my_info_screen.dart';
import '../features/profile/customer_my_reviews_screen.dart';
import '../features/profile/customer_notification_settings_screen.dart';
import '../features/profile/customer_point_history_screen.dart';
import '../features/profile/customer_profile_screen.dart';
import '../features/profile/customer_visit_history_screen.dart';
import '../features/profile/review_editor_screen.dart';
import '../features/qr/customer_qr_scanner_screen.dart';
import '../features/support/customer_support_inquiry_detail_screen.dart';
import '../features/support/customer_support_inquiry_form_screen.dart';
import '../features/support/customer_support_inquiry_list_screen.dart';
import '../features/support/customer_support_repository.dart';
import '../features/support/customer_support_screen.dart';

abstract final class CustomerRoutes {
  static const bootstrap = '/bootstrap';
  static const sessionError = '/session-error';
  static const onboardingError = '/onboarding-error';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const findId = '/find-id';
  static const findPassword = '/find-password';

  static const home = '/home';
  static const discover = '/discover';
  static const qrScanner = '/qr-scanner';
  static const favorites = '/favorites';
  static const stores = '/stores';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const profile = '/profile';
  static const myReviews = '/my-reviews';
  static const pointHistory = '/point-history';
  static const myInfo = '/my-info';
  static const visitHistory = '/visit-history';
  static const notifications = '/notifications';
  static const notificationSettings = '/notification-settings';
  static const support = '/support';
  static const supportInquiryForm = '/support/inquiries/new';
  static const supportInquiries = '/support/inquiries';

  static String supportInquiryDetail(int supportInquiryId) {
    return '$supportInquiries/$supportInquiryId';
  }

  static String orderMessages(String orderPublicId) {
    return '$orders/$orderPublicId/messages';
  }
}

GoRouter createCustomerRouter({
  required GlobalKey<NavigatorState> navigatorKey,
  required SessionController sessionController,
  required OnboardingController onboardingController,
  required StoreDiscoveryRepository storeDiscoveryRepository,
  required CatalogRepository catalogRepository,
  required PublicAnnouncementRepository announcementRepository,
  required CustomerOrderRepository orderRepository,
  required CustomerOrderMessageRepository orderMessageRepository,
  required CustomerEngagementRepository engagementRepository,
  required CustomerSupportRepository supportRepository,
  required ValueListenable<CustomerActivitySummary?> activitySummaryListenable,
  required CustomerNotificationRepository notificationRepository,
  required CartController cartController,
  required CustomerHomeController homeController,
  required CustomerPermissionGateway permissionGateway,
  required CustomerLocationRepository locationRepository,
  required String apiBaseUrl,
  required String tossClientKey,
  required Future<void> Function(String email, String password) onSignIn,
  required Future<void> Function({
    required String email,
    required String password,
    required String name,
    required String phone,
  })
  onSignUp,
  required Future<String> Function(String name, String phone) onFindId,
  required Future<void> Function(String email, String phone)
  onVerifyForPasswordReset,
  required Future<void> Function(String email, String phone, String newPassword)
  onResetPassword,
  required Future<void> Function() onConnectSellerAccess,
  required Future<void> Function(String? confirmationPhrase) onWithdraw,
  PopqThemeController? themeController,
  Future<void> Function()? onDevelopmentSignIn,
  Future<void> Function()? onGoogleSignIn,
  Future<void> Function()? onKakaoSignIn,
  Future<void> Function()? onNaverSignIn,
  Future<void> Function()? onGoogleLink,
  Future<void> Function()? onKakaoLink,
  Future<void> Function()? onNaverLink,
  Duration minSplashDuration = const Duration(seconds: 3),
}) {
  final splashStartedAt = DateTime.now();

  late final GoRouter router;
  router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: CustomerRoutes.home,
    refreshListenable: Listenable.merge([
      sessionController,
      onboardingController,
      homeController,
    ]),
    redirect: (context, state) {
      final location = state.matchedLocation;

      final isBootstrap = location == CustomerRoutes.bootstrap;

      final isSessionError = location == CustomerRoutes.sessionError;

      final isOnboardingError = location == CustomerRoutes.onboardingError;

      final isOnboarding = location == CustomerRoutes.onboarding;

      final isSignIn = location == CustomerRoutes.signIn;

      final isSignUp = location == CustomerRoutes.signUp;

      final isFindId = location == CustomerRoutes.findId;

      final isFindPassword = location == CustomerRoutes.findPassword;

      final isRestoring =
          sessionController.status == SessionStatus.restoring ||
          onboardingController.status == OnboardingStatus.restoring;

      final hasMinSplashElapsed =
          DateTime.now().difference(splashStartedAt) >= minSplashDuration;

      if (isRestoring || !hasMinSplashElapsed) {
        return isBootstrap ? null : CustomerRoutes.bootstrap;
      }

      if (sessionController.status == SessionStatus.failure) {
        return isSessionError ? null : CustomerRoutes.sessionError;
      }

      if (onboardingController.status == OnboardingStatus.failure) {
        return isOnboardingError ? null : CustomerRoutes.onboardingError;
      }

      if (!onboardingController.isComplete) {
        return isOnboarding ? null : CustomerRoutes.onboarding;
      }

      final isEnteringHome =
          isBootstrap || isSessionError || isOnboardingError || isOnboarding;

      if (isEnteringHome && !homeController.hasCompletedInitialLoad) {
        return isBootstrap ? null : CustomerRoutes.bootstrap;
      }

      if (isEnteringHome) {
        return CustomerRoutes.home;
      }

      final requiresSession =
          location == CustomerRoutes.checkout ||
              location == CustomerRoutes.orders ||
              location.startsWith(
                '${CustomerRoutes.orders}/',
              ) ||
              location == CustomerRoutes.favorites ||
              location == CustomerRoutes.profile ||
              location ==
                  CustomerRoutes.myReviews ||
              location ==
                  CustomerRoutes.pointHistory ||
              location ==
                  CustomerRoutes.myInfo ||
              location ==
                  CustomerRoutes.visitHistory ||
              location ==
                  CustomerRoutes.notifications ||
              location ==
                  CustomerRoutes.notificationSettings||
              location == CustomerRoutes.support || location.startsWith('${CustomerRoutes.support}/',);


      if (requiresSession &&
          !sessionController.isSignedIn) {
        return Uri(
          path: CustomerRoutes.signIn,
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }

      if ((isSignIn || isSignUp || isFindId || isFindPassword) &&
          sessionController.isSignedIn) {
        return state.uri.queryParameters['from'] ?? CustomerRoutes.home;
      }

      return null;
    },
    errorBuilder: (context, state) {
      return PopqErrorView(
        message: '요청한 화면을 찾을 수 없습니다.',
        onRetry: () {
          context.go(CustomerRoutes.home);
        },
      );
    },
    routes: [
      GoRoute(
        path: CustomerRoutes.bootstrap,
        builder: (context, state) {
          return const PopqSplashScreen();
        },
      ),
      GoRoute(
        path: CustomerRoutes.sessionError,
        builder: (context, state) {
          return Scaffold(
            body: PopqErrorView(
              message: '보안 저장소에서 로그인 정보를 불러오지 못했습니다.',
              onRetry: sessionController.restore,
            ),
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.onboardingError,
        builder: (context, state) {
          return Scaffold(
            body: PopqErrorView(
              message: '앱 시작 정보를 불러오지 못했습니다.',
              onRetry: onboardingController.restore,
            ),
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.onboarding,
        builder: (context, state) {
          return OnboardingScreen(
            controller: onboardingController,
            permissionGateway: permissionGateway,
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.signIn,
        builder: (context, state) {
          final returnLocation = state.uri.queryParameters['from'];

          return SignInScreen(
            onSignIn: onSignIn,
            onGoogleSignIn: onGoogleSignIn,
            onKakaoSignIn: onKakaoSignIn,
            onNaverSignIn: onNaverSignIn,
            onBackHome: () {
              context.go(CustomerRoutes.home);
            },
            onDevelopmentSignIn: onDevelopmentSignIn,
            returnLocation: returnLocation,
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.signUp,
        builder: (context, state) {
          return CustomerSignUpScreen(onSignUp: onSignUp);
        },
      ),
      GoRoute(
        path: CustomerRoutes.findId,
        builder: (context, state) {
          return CustomerFindIdScreen(onFindId: onFindId);
        },
      ),
      GoRoute(
        path: CustomerRoutes.findPassword,
        builder: (context, state) {
          return CustomerFindPasswordScreen(
            onVerify: onVerifyForPasswordReset,
            onResetPassword: onResetPassword,
          );
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.stores}/:storeId/announcements/:announcementId',
        builder: (context, state) {
          final int? storeId = int.tryParse(
            state.pathParameters['storeId'] ?? '',
          );
          final int? announcementId = int.tryParse(
            state.pathParameters['announcementId'] ?? '',
          );
          if (storeId == null || announcementId == null) {
            return const PopqErrorView(message: '공지사항 번호가 올바르지 않습니다.');
          }
          return PublicAnnouncementDetailScreen(
            storeId: storeId,
            announcementId: announcementId,
            repository: announcementRepository,
          );
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.stores}/:storeId/announcements',
        builder: (context, state) {
          final int? storeId = int.tryParse(
            state.pathParameters['storeId'] ?? '',
          );
          if (storeId == null) {
            return const PopqErrorView(message: '사업장 번호가 올바르지 않습니다.');
          }
          return PublicAnnouncementListScreen(
            storeId: storeId,
            repository: announcementRepository,
            storeRepository: storeDiscoveryRepository,
          );
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.stores}/:storeId/reviews',
        builder: (context, state) {
          final int? storeId = int.tryParse(
            state.pathParameters['storeId'] ?? '',
          );
          if (storeId == null) {
            return const PopqErrorView(message: '사업장 번호가 올바르지 않습니다.');
          }
          return StoreReviewScreen(
            storeId: storeId,
            storeRepository: storeDiscoveryRepository,
            engagementRepository: engagementRepository,
          );
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.stores}/:storeId/products/:productId',
        builder: (context, state) {
          final storeId = int.tryParse(state.pathParameters['storeId'] ?? '');

          final productId = int.tryParse(
            state.pathParameters['productId'] ?? '',
          );

          if (storeId == null || productId == null) {
            return const PopqErrorView(message: '상품 번호가 올바르지 않습니다.');
          }

          return ProductDetailScreen(
            storeId: storeId,
            productId: productId,
            repository: catalogRepository,
            storeDiscoveryRepository: storeDiscoveryRepository,
            cartController: cartController,
          );
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.stores}/:storeId/products',
        builder: (context, state) {
          final storeId = int.tryParse(state.pathParameters['storeId'] ?? '');

          if (storeId == null) {
            return const PopqErrorView(message: '스토어 번호가 올바르지 않습니다.');
          }

          return ProductListScreen(
            storeId: storeId,
            repository: catalogRepository,
            storeDiscoveryRepository: storeDiscoveryRepository,
            cartController: cartController,
          );
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.stores}/:storeId',
        builder: (context, state) {
          final storeId = int.tryParse(state.pathParameters['storeId'] ?? '');

          if (storeId == null) {
            return const PopqErrorView(message: '스토어 번호가 올바르지 않습니다.');
          }

          return StoreDetailScreen(
            storeId: storeId,
            repository: storeDiscoveryRepository,
            engagementRepository: engagementRepository,
            sessionController: sessionController,
            catalogRepository: catalogRepository,
            announcementRepository: announcementRepository,
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.cart,
        builder: (context, state) {
          return CartScreen(
            controller: cartController,
            sessionController: sessionController,
            storeDiscoveryRepository: storeDiscoveryRepository,
            onSignIn: onSignIn,
            onDevelopmentSignIn: onDevelopmentSignIn,
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.checkout,
        builder: (context, state) {
          return CheckoutScreen(
            cartController: cartController,
            orderRepository: orderRepository,
            storeDiscoveryRepository: storeDiscoveryRepository,
            tossClientKey: tossClientKey,
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.notifications,
        builder: (context, state) {
          return NotificationListScreen(repository: notificationRepository);
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.orders}/:orderPublicId/messages',
        builder: (context, state) {
          final orderPublicId = state.pathParameters['orderPublicId'] ?? '';

          if (orderPublicId.isEmpty) {
            return const PopqErrorView(message: '주문 번호가 올바르지 않습니다.');
          }

          return CustomerOrderChatScreen(
            orderPublicId: orderPublicId,
            orderRepository: orderRepository,
            messageRepository: orderMessageRepository,
            notificationRepository: notificationRepository,
          );
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.orders}/:orderPublicId/review',
        builder: (context, state) {
          return ReviewEditorScreen(
            orderPublicId: state.pathParameters['orderPublicId'] ?? '',
            repository: engagementRepository,
          );
        },
      ),
      GoRoute(
        path: '${CustomerRoutes.orders}/:orderPublicId',
        builder: (context, state) {
          return OrderDetailScreen(
            orderPublicId: state.pathParameters['orderPublicId'] ?? '',
            repository: orderRepository,
            messageRepository: orderMessageRepository,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return CustomerRootScreen(
            location: state.uri.path,
            notificationRepository: notificationRepository,
            orderMessageRepository: orderMessageRepository,
            sessionController: sessionController,
            themeController: themeController,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: CustomerRoutes.home,
            builder: (context, state) {
              return CustomerHomeScreen(
                storeDiscoveryRepository: storeDiscoveryRepository,
                orderRepository: orderRepository,
                sessionController: sessionController,
                permissionGateway: permissionGateway,
                locationRepository: locationRepository,
                preloadedController: homeController,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.discover,
            builder: (context, state) {
              return StoreDiscoveryScreen(
                repository: storeDiscoveryRepository,
                permissionGateway: permissionGateway,
                engagementRepository: engagementRepository,
                sessionController: sessionController,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.qrScanner,
            builder: (context, state) {
              return CustomerQrScannerScreen(
                apiBaseUrl: apiBaseUrl,
                engagementRepository: engagementRepository,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.favorites,
            builder: (context, state) {
              return CustomerFavoriteStoreScreen(
                repository: engagementRepository,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.orders,
            builder: (context, state) {
              return OrderListScreen(
                repository: orderRepository,
                messageRepository: orderMessageRepository,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.myReviews,
            builder: (context, state) {
              return CustomerMyReviewsScreen(repository: engagementRepository);
            },
          ),
          GoRoute(
            path: CustomerRoutes.pointHistory,
            builder: (context, state) {
              return CustomerPointHistoryScreen(
                repository: engagementRepository,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.myInfo,
            builder: (context, state) {
              return CustomerMyInfoScreen(
                repository: engagementRepository,
                onSignOut: sessionController.signOut,
                onGoogleLink: onGoogleLink,
                onKakaoLink: onKakaoLink,
                onNaverLink: onNaverLink,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.visitHistory,
            builder: (context, state) {
              return CustomerVisitHistoryScreen(
                repository: engagementRepository,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.notificationSettings,
            builder: (context, state) {
              return CustomerNotificationSettingsScreen(
                repository: engagementRepository,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.support,
            builder: (context, state) {
              return CustomerSupportScreen(
                repository: supportRepository,
                onCreateInquiry: () {
                  context.push(
                    CustomerRoutes.supportInquiryForm,
                  );
                },
                onMyInquiries: () {
                  context.push(
                    CustomerRoutes.supportInquiries,
                  );
                },
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.supportInquiryForm,
            builder: (context, state) {
              return FutureBuilder<CustomerProfile>(
                future: engagementRepository.getProfile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState !=
                      ConnectionState.done) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError ||
                      snapshot.data == null) {
                    return Scaffold(
                      appBar: AppBar(
                        title: const Text('1:1 문의하기'),
                      ),
                      body: const Center(
                        child: Text(
                          '회원 정보를 불러오지 못했어요.',
                        ),
                      ),
                    );
                  }

                  return CustomerSupportInquiryFormScreen(
                    repository: supportRepository,
                    customerEmail: snapshot.data!.email,
                    onCreated: (created) {
                      context.pushReplacement(
                        CustomerRoutes.supportInquiryDetail(
                          created.inquiry.supportInquiryId,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.supportInquiries,
            builder: (context, state) {
              return CustomerSupportInquiryListScreen(
                repository: supportRepository,
                onInquiryTap: (supportInquiryId) {
                  context.push(
                    CustomerRoutes.supportInquiryDetail(
                      supportInquiryId,
                    ),
                  );
                },
              );
            },
          ),
          GoRoute(
            path: '/support/inquiries/:supportInquiryId',
            builder: (context, state) {
              final supportInquiryId = int.tryParse(
                state.pathParameters[
                'supportInquiryId'] ??
                    '',
              );

              if (supportInquiryId == null ||
                  supportInquiryId <= 0) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('문의 상세'),
                  ),
                  body: const Center(
                    child: Text(
                      '올바르지 않은 문의 번호예요.',
                    ),
                  ),
                );
              }

              return CustomerSupportInquiryDetailScreen(
                repository: supportRepository,
                supportInquiryId: supportInquiryId,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.profile,
            builder: (context, state) {
              return CustomerProfileScreen(
                repository: engagementRepository,
                activitySummaryListenable: activitySummaryListenable,
                messageRepository: orderMessageRepository,
                onSignOut: sessionController.signOut,
                onConnectSellerAccess: onConnectSellerAccess,
                onWithdraw: onWithdraw,
              );
            },
          ),
        ],
      ),
    ],
  );

  Timer(minSplashDuration, router.refresh);

  return router;
}
