import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../features/auth/seller_bootstrap_controller.dart';
import '../features/auth/seller_sign_in_screen.dart';
import '../features/common/seller_section_placeholder.dart';
import '../features/home/seller_home_screen.dart';
import '../features/orders/seller_order_detail_screen.dart';
import '../features/orders/seller_order_list_screen.dart';
import '../features/orders/seller_order_repository.dart';
import '../features/stores/seller_store_repository.dart';
import '../features/stores/seller_store_selection_controller.dart';
import '../features/stores/store_selection_screen.dart';
import '../seller_root_screen.dart';

abstract final class SellerRoutes {
  static const bootstrap = '/bootstrap';
  static const bootstrapError = '/bootstrap-error';
  static const signIn = '/sign-in';
  static const home = '/home';
  static const orders = '/orders';
  static const products = '/products';
  static const stores = '/stores';
}

GoRouter createSellerRouter({
  required SessionController sessionController,
  required SellerBootstrapController bootstrapController,
  required SellerStoreSelectionController storeSelectionController,
  required SellerStoreRepository storeRepository,
  required SellerOrderRepository orderRepository,
  required Future<void> Function() onSignOut,
  Future<void> Function()? onDevelopmentSignIn,
}) {
  return GoRouter(
    initialLocation: SellerRoutes.home,
    refreshListenable: Listenable.merge([
      bootstrapController,
      sessionController,
      storeSelectionController,
    ]),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isBootstrap = location == SellerRoutes.bootstrap;
      final isBootstrapError = location == SellerRoutes.bootstrapError;
      final isSignIn = location == SellerRoutes.signIn;

      if (bootstrapController.status == SellerBootstrapStatus.restoring) {
        return isBootstrap ? null : SellerRoutes.bootstrap;
      }
      if (bootstrapController.status == SellerBootstrapStatus.failure) {
        return isBootstrapError ? null : SellerRoutes.bootstrapError;
      }
      if (isBootstrap || isBootstrapError) {
        if (!sessionController.isSignedIn) return SellerRoutes.signIn;
        return storeSelectionController.hasSelection
            ? SellerRoutes.home
            : SellerRoutes.stores;
      }
      if (!sessionController.isSignedIn) {
        return isSignIn ? null : SellerRoutes.signIn;
      }
      if (isSignIn) {
        if (!storeSelectionController.hasSelection) {
          return SellerRoutes.stores;
        }
        return state.uri.queryParameters['from'] ?? SellerRoutes.home;
      }
      if (!storeSelectionController.hasSelection &&
          location != SellerRoutes.stores) {
        return SellerRoutes.stores;
      }
      return null;
    },
    errorBuilder: (context, state) {
      return PopqErrorView(
        message: '요청한 판매자 화면을 찾을 수 없어요.',
        onRetry: () => context.go(SellerRoutes.home),
      );
    },
    routes: [
      GoRoute(
        path: SellerRoutes.bootstrap,
        builder: (context, state) {
          return const Scaffold(
            body: PopqLoadingView(message: '판매자 계정과 스토어를 확인하고 있어요.'),
          );
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
            roleMismatch: bootstrapController.roleMismatch,
            onDevelopmentSignIn: onDevelopmentSignIn,
          );
        },
      ),
      GoRoute(
        path: '${SellerRoutes.orders}/:orderPublicId',
        builder: (context, state) {
          return SellerOrderDetailScreen(
            orderPublicId: state.pathParameters['orderPublicId']!,
            repository: orderRepository,
            selectionController: storeSelectionController,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return SellerRootScreen(
            location: state.uri.path,
            onSignOut: onSignOut,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: SellerRoutes.home,
            builder: (context, state) {
              return SellerHomeScreen(
                repository: storeRepository,
                selectionController: storeSelectionController,
              );
            },
          ),
          GoRoute(
            path: SellerRoutes.orders,
            builder: (context, state) {
              return SellerOrderListScreen(
                repository: orderRepository,
                selectionController: storeSelectionController,
              );
            },
          ),
          GoRoute(
            path: SellerRoutes.products,
            builder: (context, state) {
              return const SellerSectionPlaceholder(
                icon: Icons.inventory_2_outlined,
                title: '상품·품절',
                description: '판매 상태와 빠른 품절 처리는 9.6C에서 연결합니다.',
              );
            },
          ),
          GoRoute(
            path: SellerRoutes.stores,
            builder: (context, state) {
              return StoreSelectionScreen(
                repository: storeRepository,
                controller: storeSelectionController,
              );
            },
          ),
        ],
      ),
    ],
  );
}
