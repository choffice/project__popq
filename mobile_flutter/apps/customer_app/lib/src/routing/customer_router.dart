import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../customer_root_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/cart/cart_controller.dart';
import '../features/cart/cart_screen.dart';
import '../features/catalog/catalog_repository.dart';
import '../features/catalog/product_detail_screen.dart';
import '../features/catalog/product_list_screen.dart';
import '../features/discovery/store_detail_screen.dart';
import '../features/discovery/store_discovery_repository.dart';
import '../features/discovery/store_discovery_screen.dart';
import '../features/favorites/customer_favorite_store_screen.dart';
import '../features/home/customer_home_screen.dart';
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
import '../features/profile/customer_profile_screen.dart';
import '../features/profile/review_editor_screen.dart';
import '../features/qr/customer_qr_scanner_screen.dart';

abstract final class CustomerRoutes {
  static const bootstrap = '/bootstrap';
  static const sessionError = '/session-error';
  static const onboardingError = '/onboarding-error';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';

  static const home = '/home';
  static const discover = '/discover';
  static const qrScanner = '/qr-scanner';
  static const favorites = '/favorites';
  static const stores = '/stores';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const profile = '/profile';
  static const notifications = '/notifications';
}

GoRouter createCustomerRouter({
  required SessionController sessionController,
  required OnboardingController onboardingController,
  required StoreDiscoveryRepository storeDiscoveryRepository,
  required CatalogRepository catalogRepository,
  required CustomerOrderRepository orderRepository,
  required CustomerEngagementRepository engagementRepository,
  required CustomerNotificationRepository notificationRepository,
  required CartController cartController,
  required CustomerPermissionGateway permissionGateway,
  required String tossClientKey,
  PopqThemeController? themeController,
  Future<void> Function()? onDevelopmentSignIn,
  Future<void> Function()? onGoogleSignIn,
  Future<void> Function()? onKakaoSignIn,
  Future<void> Function()? onNaverSignIn,
}) {
  return GoRouter(
    initialLocation: CustomerRoutes.home,
    refreshListenable: Listenable.merge([
      sessionController,
      onboardingController,
    ]),
    redirect: (context, state) {
      final location = state.matchedLocation;

      final isBootstrap =
          location == CustomerRoutes.bootstrap;

      final isSessionError =
          location == CustomerRoutes.sessionError;

      final isOnboardingError =
          location == CustomerRoutes.onboardingError;

      final isOnboarding =
          location == CustomerRoutes.onboarding;

      final isSignIn =
          location == CustomerRoutes.signIn;

      final isRestoring =
          sessionController.status ==
              SessionStatus.restoring ||
              onboardingController.status ==
                  OnboardingStatus.restoring;

      if (isRestoring) {
        return isBootstrap
            ? null
            : CustomerRoutes.bootstrap;
      }

      if (sessionController.status ==
          SessionStatus.failure) {
        return isSessionError
            ? null
            : CustomerRoutes.sessionError;
      }

      if (onboardingController.status ==
          OnboardingStatus.failure) {
        return isOnboardingError
            ? null
            : CustomerRoutes.onboardingError;
      }

      if (!onboardingController.isComplete) {
        return isOnboarding
            ? null
            : CustomerRoutes.onboarding;
      }

      if (isBootstrap ||
          isSessionError ||
          isOnboardingError ||
          isOnboarding) {
        return CustomerRoutes.home;
      }

      final requiresSession =
          location == CustomerRoutes.checkout ||
              location == CustomerRoutes.orders ||
              location.startsWith(
                '${CustomerRoutes.orders}/',
              ) ||
              location ==
                  CustomerRoutes.favorites ||
              location ==
                  CustomerRoutes.profile ||
              location ==
                  CustomerRoutes.notifications;

      /*
       * 주문, 찜, 마이페이지와 알림처럼
       * 고객 로그인 정보가 필요한 화면을 보호합니다.
       */
      if (requiresSession &&
          !sessionController.isSignedIn) {
        return Uri(
          path: CustomerRoutes.signIn,
          queryParameters: {
            'from': state.uri.toString(),
          },
        ).toString();
      }

      /*
       * 로그인에 성공하면 사용자가 원래 접근하려던
       * 화면으로 돌아갑니다.
       */
      if (isSignIn &&
          sessionController.isSignedIn) {
        return state.uri.queryParameters['from'] ??
            CustomerRoutes.home;
      }

      return null;
    },
    errorBuilder: (context, state) {
      return PopqErrorView(
        message: '요청한 화면을 찾을 수 없습니다.',
        onRetry: () {
          context.go(
            CustomerRoutes.home,
          );
        },
      );
    },
    routes: [
      GoRoute(
        path: CustomerRoutes.bootstrap,
        builder: (context, state) {
          return const Scaffold(
            body: PopqLoadingView(
              message: '앱을 준비하고 있어요.',
            ),
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.sessionError,
        builder: (context, state) {
          return Scaffold(
            body: PopqErrorView(
              message:
              '보안 저장소에서 로그인 정보를 불러오지 못했습니다.',
              onRetry:
              sessionController.restore,
            ),
          );
        },
      ),
      GoRoute(
        path:
        CustomerRoutes.onboardingError,
        builder: (context, state) {
          return Scaffold(
            body: PopqErrorView(
              message:
              '앱 시작 정보를 불러오지 못했습니다.',
              onRetry:
              onboardingController.restore,
            ),
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.onboarding,
        builder: (context, state) {
          return OnboardingScreen(
            controller:
            onboardingController,
            permissionGateway:
            permissionGateway,
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.signIn,
        builder: (context, state) {
          final returnLocation =
          state.uri.queryParameters['from'];

          return SignInScreen(
            onGoogleSignIn: onGoogleSignIn,
            onKakaoSignIn: onKakaoSignIn,
            onNaverSignIn: onNaverSignIn,
            onBackHome: () {
              context.go(
                CustomerRoutes.home,
              );
            },
            onDevelopmentSignIn:
            onDevelopmentSignIn,
            returnLocation:
            returnLocation,
          );
        },
      ),
      GoRoute(
        path:
        '${CustomerRoutes.stores}/:storeId/products/:productId',
        builder: (context, state) {
          final storeId = int.tryParse(
            state.pathParameters['storeId'] ??
                '',
          );

          final productId = int.tryParse(
            state.pathParameters[
            'productId'] ??
                '',
          );

          if (storeId == null ||
              productId == null) {
            return const PopqErrorView(
              message:
              '상품 번호가 올바르지 않습니다.',
            );
          }

          return ProductDetailScreen(
            storeId: storeId,
            productId: productId,
            repository:
            catalogRepository,
            cartController:
            cartController,
          );
        },
      ),
      GoRoute(
        path:
        '${CustomerRoutes.stores}/:storeId/products',
        builder: (context, state) {
          final storeId = int.tryParse(
            state.pathParameters['storeId'] ??
                '',
          );

          if (storeId == null) {
            return const PopqErrorView(
              message:
              '스토어 번호가 올바르지 않습니다.',
            );
          }

          return ProductListScreen(
            storeId: storeId,
            repository:
            catalogRepository,
            cartController:
            cartController,
          );
        },
      ),
      GoRoute(
        path:
        '${CustomerRoutes.stores}/:storeId',
        builder: (context, state) {
          final storeId = int.tryParse(
            state.pathParameters['storeId'] ??
                '',
          );

          if (storeId == null) {
            return const PopqErrorView(
              message:
              '스토어 번호가 올바르지 않습니다.',
            );
          }

          return StoreDetailScreen(
            storeId: storeId,
            repository:
            storeDiscoveryRepository,
            engagementRepository:
            engagementRepository,
            sessionController:
            sessionController,
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.cart,
        builder: (context, state) {
          return CartScreen(
            controller:
            cartController,
            sessionController:
            sessionController,
            onDevelopmentSignIn:
            onDevelopmentSignIn,
          );
        },
      ),
      GoRoute(
        path: CustomerRoutes.checkout,
        builder: (context, state) {
          return CheckoutScreen(
            cartController:
            cartController,
            orderRepository:
            orderRepository,
            tossClientKey:
            tossClientKey,
          );
        },
      ),
      GoRoute(
        path:
        CustomerRoutes.notifications,
        builder: (context, state) {
          return NotificationListScreen(
            repository:
            notificationRepository,
          );
        },
      ),
      GoRoute(
        path:
        '${CustomerRoutes.orders}/:orderPublicId/review',
        builder: (context, state) {
          return ReviewEditorScreen(
            orderPublicId:
            state.pathParameters[
            'orderPublicId'] ??
                '',
            repository:
            engagementRepository,
          );
        },
      ),
      GoRoute(
        path:
        '${CustomerRoutes.orders}/:orderPublicId',
        builder: (context, state) {
          return OrderDetailScreen(
            orderPublicId:
            state.pathParameters[
            'orderPublicId'] ??
                '',
            repository:
            orderRepository,
          );
        },
      ),
      ShellRoute(
        builder: (
            context,
            state,
            child,
            ) {
          return CustomerRootScreen(
            location: state.uri.path,
            notificationRepository:
            notificationRepository,
            sessionController:
            sessionController,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: CustomerRoutes.home,
            builder: (context, state) {
              return CustomerHomeScreen(
                storeDiscoveryRepository:
                storeDiscoveryRepository,
                orderRepository:
                orderRepository,
                sessionController:
                sessionController,
              );
            },
          ),
          GoRoute(
            path:
            CustomerRoutes.discover,
            builder: (context, state) {
              return StoreDiscoveryScreen(
                repository:
                storeDiscoveryRepository,
                permissionGateway:
                permissionGateway,

                /*
                 * 탐색 화면 하트를 실제 DB 찜 기능과
                 * 연결하기 위해 전달합니다.
                 */
                engagementRepository:
                engagementRepository,
                sessionController:
                sessionController,
              );
            },
          ),

          /*
           * 기존 QR 화면과 라우트는 수정하지 않습니다.
           */
          GoRoute(
            path:
            CustomerRoutes.qrScanner,
            builder: (context, state) {
              return const CustomerQrScannerScreen();
            },
          ),

          GoRoute(
            path:
            CustomerRoutes.favorites,
            builder: (context, state) {
              return CustomerFavoriteStoreScreen(
                repository:
                engagementRepository,
              );
            },
          ),

          /*
           * 하단 탭에서는 빠졌지만 주문 목록 경로는
           * 홈과 마이페이지에서 계속 사용합니다.
           */
          GoRoute(
            path: CustomerRoutes.orders,
            builder: (context, state) {
              return OrderListScreen(
                repository:
                orderRepository,
              );
            },
          ),
          GoRoute(
            path: CustomerRoutes.profile,
            builder: (context, state) {
              return CustomerProfileScreen(
                repository:
                engagementRepository,
                onSignOut:
                sessionController.signOut,
                themeController:
                themeController,
              );
            },
          ),
        ],
      ),
    ],
  );
}