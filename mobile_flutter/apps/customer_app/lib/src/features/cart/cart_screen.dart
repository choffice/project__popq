import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import '../../routing/customer_router.dart';
import '../auth/sign_in_screen.dart';
import 'cart_controller.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    required this.controller,
    required this.sessionController,
    required this.onSignIn,
    this.onDevelopmentSignIn,
    super.key,
  });

  final CartController controller;
  final SessionController sessionController;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function()? onDevelopmentSignIn;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  var _openingCheckout = false;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_changed);
    widget.sessionController.addListener(_changed);
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

    setState(() {});
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
          : ListView.separated(
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
                        onPressed:
                        !_openingCheckout &&
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
      bottomNavigationBar: widget.controller.isEmpty
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PopqSpacing.md),
          child: FilledButton(
            onPressed: _openingCheckout
                ? null
                : _openCheckout,
            child: Text(
              _openingCheckout
                  ? '로그인 정보를 확인하고 있어요...'
                  : '${_won(widget.controller.totalAmount)} · 주문하기',
            ),
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
    } finally {
      if (mounted) {
        setState(() {
          _openingCheckout = false;
        });
      }
    }
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