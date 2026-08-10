import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../auth/sign_in_screen.dart';
import '../discovery/store_discovery_repository.dart';
import 'cart_controller.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    required this.controller,
    required this.sessionController,
    required this.storeDiscoveryRepository,
    required this.onSignIn,
    this.onDevelopmentSignIn,
    super.key,
  });

  final CartController controller;
  final SessionController sessionController;
  final StoreDiscoveryRepository storeDiscoveryRepository;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function()? onDevelopmentSignIn;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  var _openingCheckout = false;
  Future<CustomerStore>? _storeFuture;
  int? _storeFutureId;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_changed);
    widget.sessionController.addListener(_changed);
    _syncStoreFuture(force: true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.sessionController.removeListener(_changed);

    super.dispose();
  }

  void _changed() {
    if (!mounted) {
      return;
    }

    _syncStoreFuture();
    setState(() {});
  }

  void _syncStoreFuture({bool force = false}) {
    final storeId = widget.controller.storeId;

    if (storeId == null) {
      _storeFutureId = null;
      _storeFuture = null;
      return;
    }

    if (force || _storeFutureId != storeId) {
      _storeFutureId = storeId;
      _storeFuture = widget.storeDiscoveryRepository.findDetail(storeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장바구니'),
        actions: [
          if (!widget.controller.isEmpty)
            TextButton(
              onPressed: _openingCheckout
                  ? null
                  : widget.controller.clear,
              child: const Text('전체 삭제'),
            ),
        ],
      ),
      body: widget.controller.isEmpty
          ? const PopqEmptyView(
        icon: Icons.shopping_bag_outlined,
        title: '장바구니가 비어 있어요.',
        description: '스토어에서 원하는 상품을 담아보세요.',
      )
          : Column(
              children: [
                FutureBuilder<CustomerStore>(
                  future: _storeFuture,
                  builder: (context, snapshot) {
                    final store = snapshot.data;
                    if (store == null || store.orderAcceptingEnabled) {
                      return const SizedBox.shrink();
                    }

                    return const Padding(
                      padding: EdgeInsets.fromLTRB(
                        PopqSpacing.md,
                        PopqSpacing.md,
                        PopqSpacing.md,
                        0,
                      ),
                      child: _OrderPausedBanner(),
                    );
                  },
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(PopqSpacing.md),
                    itemCount: widget.controller.items.length,
                    separatorBuilder: (_, _) {
                      return const SizedBox(
                        height: PopqSpacing.sm,
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = widget.controller.items[index];

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(PopqSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.product.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  Text(
                                    _won(item.totalPrice),
                                  ),
                                ],
                              ),
                              if (item.options.isNotEmpty) ...[
                                const SizedBox(
                                  height: PopqSpacing.xs,
                                ),
                                Text(
                                  item.options
                                      .map(
                                        (option) => option.name,
                                      )
                                      .join(', '),
                                ),
                              ],
                              const SizedBox(
                                height: PopqSpacing.sm,
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _openingCheckout
                                        ? null
                                        : () {
                                            widget.controller.changeQuantity(
                                              item,
                                              item.quantity - 1,
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    onPressed: !_openingCheckout &&
                                            item.quantity < 99
                                        ? () {
                                            widget.controller.changeQuantity(
                                              item,
                                              item.quantity + 1,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _openingCheckout
                                        ? null
                                        : () {
                                            widget.controller.changeQuantity(
                                              item,
                                              0,
                                            );
                                          },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                    ),
                                    label: const Text('삭제'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: widget.controller.isEmpty
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: FutureBuilder<CustomerStore>(
            future: _storeFuture,
            builder: (context, snapshot) {
              final store = snapshot.data;
              final checking =
                  snapshot.connectionState != ConnectionState.done;
              final paused = store != null && !store.orderAcceptingEnabled;

              return FilledButton(
                onPressed: _openingCheckout || checking || paused
                    ? null
                    : _openCheckout,
                child: Text(
                  _openingCheckout
                      ? '주문 가능 여부를 확인하고 있어요...'
                      : checking
                          ? '주문 가능 여부 확인 중...'
                          : paused
                              ? '현재 주문 접수 중지'
                              : '${_won(widget.controller.totalAmount)} · 주문하기',
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openCheckout() async {
    if (_openingCheckout || widget.controller.isEmpty) {
      return;
    }

    setState(() {
      _openingCheckout = true;
    });

    try {
      final storeId = widget.controller.storeId;
      if (storeId == null) {
        return;
      }

      final store = await widget.storeDiscoveryRepository.findDetail(storeId);

      if (!mounted) {
        return;
      }

      setState(() {
        _storeFutureId = storeId;
        _storeFuture = Future<CustomerStore>.value(store);
      });

      if (!store.orderAcceptingEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('현재 매장이 신규 주문 접수를 잠시 중지했어요.'),
          ),
        );
        return;
      }

      if (!widget.sessionController.isSignedIn) {
        final rootNavigator = Navigator.of(
          context,
          rootNavigator: true,
        );

        /*
         * GoRouter의 /sign-in 경로를 사용하지 않습니다.
         *
         * 로그인 화면을 일반 전체 화면 모달로 열기 때문에
         * 로그인 완료 후 모달을 pop하면 로그인 페이지가
         * GoRouter 뒤로가기 기록에 남지 않습니다.
         */
        final signedIn = await rootNavigator.push<bool>(
          MaterialPageRoute<bool>(
            fullscreenDialog: true,
            builder: (signInContext) {
              return SignInScreen(
                onSignIn: widget.onSignIn,
                onBackHome: () {
                  final navigator = Navigator.of(
                    signInContext,
                  );

                  if (navigator.canPop()) {
                    navigator.pop(false);
                  }
                },
                onDevelopmentSignIn:
                widget.onDevelopmentSignIn,
                returnResultOnSuccess: true,
              );
            },
          ),
        );

        if (!mounted) {
          return;
        }

        if (signedIn != true ||
            !widget.sessionController.isSignedIn) {
          return;
        }
      }

      if (!mounted) {
        return;
      }

      /*
       * 로그인 모달이 완전히 제거된 후에만
       * 결제 화면을 장바구니 위에 push합니다.
       *
       * 화면 기록:
       * 상품/매장 → 장바구니 → 결제
       */
      await context.push<void>(
        CustomerRoutes.checkout,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '주문 가능 여부를 확인하지 못했어요. 잠시 후 다시 시도해주세요.\n$error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingCheckout = false;
        });
      }
    }
  }
}


class _OrderPausedBanner extends StatelessWidget {
  const _OrderPausedBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PopqSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: PopqSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 주문 접수가 잠시 중단되었어요.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '장바구니는 유지됩니다. 접수가 다시 시작되면 주문할 수 있어요.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _won(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 &&
        (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }

    buffer.write(digits[index]);
  }

  return '$buffer원';
}