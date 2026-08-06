import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../features/announcements/seller_announcement_repository.dart';
import '../features/auth/seller_bootstrap_controller.dart';
import '../features/auth/seller_find_id_screen.dart';
import '../features/auth/seller_find_password_screen.dart';
import '../features/auth/seller_sign_in_screen.dart';
import '../features/auth/seller_sign_up_screen.dart';
import '../features/customers/seller_customer_chat_screen.dart';
import '../features/customers/seller_customer_repository.dart';
import '../features/customers/seller_customer_screen.dart';
import '../features/home/seller_analytics_repository.dart';
import '../features/operations/seller_operation_screen.dart';
import '../features/orders/seller_order_detail_screen.dart';
import '../features/orders/seller_order_list_screen.dart';
import '../features/orders/seller_order_repository.dart';
import '../features/products/seller_product_repository.dart';
import '../features/profile/seller_my_screen.dart';
import '../features/profile/seller_profile_screen.dart';
import '../features/settings/seller_settings_screen.dart';
import '../features/stores/seller_store_registration_screen.dart';
import '../features/stores/seller_store_repository.dart';
import '../features/stores/seller_store_selection_controller.dart';
import '../features/stores/store_selection_screen.dart';
import '../seller_root_screen.dart';

abstract final class SellerRoutes {
  static const bootstrap = '/bootstrap';
  static const bootstrapError = '/bootstrap-error';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const findId = '/find-id';
  static const findPassword = '/find-password';
  static const dashboard = '/dashboard';
  static const storeRegistration = '/stores/register';
  static const operations = '/operations';
  static const orders = '/orders';
  static const customers = '/customers';
  static const my = '/my';
  static const myProfile = '/my/profile';

  @Deprecated('마이 탭 경로는 SellerRoutes.my를 사용하세요.')
  static const sales = my;

  static const settings = '/settings';
}

GoRouter createSellerRouter({
  required SessionController sessionController,
  required SellerBootstrapController bootstrapController,
  required SellerStoreSelectionController storeSelectionController,
  required SellerStoreRepository storeRepository,
  required SellerAnnouncementRepository announcementRepository,
  required SellerOrderRepository orderRepository,
  required SellerProductRepository productRepository,
  required SellerAnalyticsRepository analyticsRepository,
  required SellerCustomerRepository customerRepository,
  required Future<void> Function() onSignOut,
  required Future<void> Function(String? confirmationPhrase) onWithdraw,
  required Future<void> Function() onConnectCustomerAccess,
  required Future<void> Function(
      String email,
      String password,
      )
  onSignIn,
  required Future<void> Function({
  required String email,
  required String password,
  required String name,
  required String phone,
  })
  onSignUp,
  required Future<String> Function(
      String name,
      String phone,
      )
  onFindId,
  required Future<void> Function(
      String email,
      String phone,
      )
  onVerifyForPasswordReset,
  required Future<void> Function(
      String email,
      String phone,
      String newPassword,
      )
  onResetPassword,
  PopqThemeController? themeController,
  Future<void> Function()? onDevelopmentSignIn,
  Future<void> Function()? onGoogleSignIn,
  Future<void> Function()? onKakaoSignIn,
  Future<void> Function()? onNaverSignIn,
  Duration minSplashDuration = const Duration(seconds: 3),
}) {
  final splashStartedAt = DateTime.now();

  late final GoRouter router;
  router = GoRouter(
    initialLocation: SellerRoutes.dashboard,
    refreshListenable: Listenable.merge([
      bootstrapController,
      sessionController,
      storeSelectionController,
    ]),
    redirect: (context, state) {
      final location = state.matchedLocation;

      final isBootstrap =
          location == SellerRoutes.bootstrap;

      final isBootstrapError =
          location == SellerRoutes.bootstrapError;

      final isSignIn =
          location == SellerRoutes.signIn;

      final isSignUp =
          location == SellerRoutes.signUp;

      final isFindId =
          location == SellerRoutes.findId;

      final isFindPassword =
          location == SellerRoutes.findPassword;

      final isPreLoginAuthScreen =
          isSignIn ||
              isSignUp ||
              isFindId ||
              isFindPassword;

      final isStoreRegistration =
          location == SellerRoutes.storeRegistration;

      final hasMinSplashElapsed =
          DateTime.now().difference(splashStartedAt) >=
              minSplashDuration;

      if (bootstrapController.status ==
          SellerBootstrapStatus.restoring ||
          !hasMinSplashElapsed) {
        return isBootstrap
            ? null
            : SellerRoutes.bootstrap;
      }

      if (bootstrapController.status ==
          SellerBootstrapStatus.failure) {
        return isBootstrapError
            ? null
            : SellerRoutes.bootstrapError;
      }

      if (isBootstrap || isBootstrapError) {
        if (!sessionController.isSignedIn) {
          return SellerRoutes.signIn;
        }

        return SellerRoutes.dashboard;
      }

      if (!sessionController.isSignedIn) {
        return isPreLoginAuthScreen
            ? null
            : SellerRoutes.signIn;
      }

      if (isPreLoginAuthScreen) {
        return state.uri.queryParameters['from'] ??
            SellerRoutes.dashboard;
      }

      if (!storeSelectionController.hasSelection &&
          location != SellerRoutes.dashboard &&
          location != SellerRoutes.customers &&
          location != SellerRoutes.my &&
          location != SellerRoutes.settings &&
          !isStoreRegistration) {
        return SellerRoutes.dashboard;
      }

      return null;
    },
    errorBuilder: (context, state) {
      return PopqErrorView(
        message: '요청한 판매자 화면을 찾을 수 없어요.',
        onRetry: () {
          context.go(
            SellerRoutes.dashboard,
          );
        },
      );
    },
    routes: [
      GoRoute(
        path: SellerRoutes.bootstrap,
        builder: (context, state) {
          return const PopqSplashScreen();
        },
      ),
      GoRoute(
        path: SellerRoutes.bootstrapError,
        builder: (context, state) {
          return Scaffold(
            body: PopqErrorView(
              message: '판매자 세션 또는 스토어 선택 정보를 복원하지 못했어요.',
              onRetry: bootstrapController.restore,
            ),
          );
        },
      ),
      GoRoute(
        path: SellerRoutes.signIn,
        builder: (context, state) {
          return SellerSignInScreen(
            roleMismatch:
            bootstrapController.roleMismatch,
            onSignIn: onSignIn,
            onDevelopmentSignIn:
            onDevelopmentSignIn,
            onGoogleSignIn: onGoogleSignIn,
            onKakaoSignIn : onKakaoSignIn,
            onNaverSignIn : onNaverSignIn,
          );
        },
      ),
      GoRoute(
        path: SellerRoutes.signUp,
        builder: (context, state) {
          return SellerSignUpScreen(
            onSignUp: onSignUp,
          );
        },
      ),
      GoRoute(
        path: SellerRoutes.findId,
        builder: (context, state) {
          return SellerFindIdScreen(
            onFindId: onFindId,
          );
        },
      ),
      GoRoute(
        path: SellerRoutes.findPassword,
        builder: (context, state) {
          return SellerFindPasswordScreen(
            onVerify: onVerifyForPasswordReset,
            onResetPassword: onResetPassword,
          );
        },
      ),
      GoRoute(
        path: SellerRoutes.myProfile,
        builder: (context, state) {
          return SellerProfileScreen(
            identityRepository: bootstrapController.identityRepository,
          );
        },
      ),
      GoRoute(
        path: SellerRoutes.settings,
        builder: (context, state) {
          final controller = themeController;

          if (controller == null) {
            return PopqErrorView(
              message: '화면 설정을 준비하지 못했어요.',
              onRetry: () {
                context.go(
                  SellerRoutes.dashboard,
                );
              },
            );
          }

          return SellerSettingsScreen(
            themeController: controller,
          );
        },
      ),
      GoRoute(
        path: SellerRoutes.storeRegistration,
        builder: (context, state) {
          return SellerStoreRegistrationScreen(
            repository: storeRepository,
            selectionController:
            storeSelectionController,
          );
        },
      ),
      GoRoute(
        path:
        '${SellerRoutes.orders}/:orderPublicId',
        builder: (context, state) {
          return SellerOrderDetailScreen(
            orderPublicId:
            state.pathParameters[
            'orderPublicId'
            ]!,
            repository: orderRepository,
            storeRepository: storeRepository,
            selectionController:
            storeSelectionController,
          );
        },
      ),
      GoRoute(
        path:
        '${SellerRoutes.customers}/:orderPublicId',
        builder: (context, state) {
          return SellerCustomerChatScreen(
            orderPublicId:
            state.pathParameters[
            'orderPublicId'
            ]!,
            repository: customerRepository,
            selectionController:
            storeSelectionController,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return SellerRootScreen(
            location: state.uri.path,
            onSignOut: onSignOut,
            customerRepository:
            customerRepository,
            storeSelectionController:
            storeSelectionController,
            themeController: themeController,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: SellerRoutes.dashboard,
            builder: (context, state) {
              return StoreSelectionScreen(
                repository: storeRepository,
                controller:
                storeSelectionController,
              );
            },
          ),
          GoRoute(
            path: SellerRoutes.operations,
            builder: (context, state) {
              return SellerOperationScreen(
                storeRepository:
                storeRepository,
                announcementRepository:
                announcementRepository,
                productRepository:
                productRepository,
                analyticsRepository:
                analyticsRepository,
                selectionController:
                storeSelectionController,
              );
            },
          ),
          GoRoute(
            path: SellerRoutes.orders,
            builder: (context, state) {
              return SellerOrderListScreen(
                repository: orderRepository,
                selectionController:
                storeSelectionController,
              );
            },
          ),
          GoRoute(
            path: SellerRoutes.customers,
            builder: (context, state) {
              return SellerCustomerScreen(
                repository:
                customerRepository,
                selectionController:
                storeSelectionController,
              );
            },
          ),
          GoRoute(
            path: SellerRoutes.my,
            builder: (context, state) {
              return SellerMyScreen(
                storeRepository:
                storeRepository,
                selectionController:
                storeSelectionController,
                identityRepository:
                bootstrapController.identityRepository,
                onSignOut: onSignOut,
                onWithdraw: onWithdraw,
                onConnectCustomerAccess: onConnectCustomerAccess,
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