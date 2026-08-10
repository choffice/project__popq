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
        title: const Text('?λ컮援щ땲'),
        actions: [
          if (!widget.controller.isEmpty)
            TextButton(
              onPressed: _openingCheckout
                  ? null
                  : widget.controller.clear,
              child: const Text('?꾩껜 ??젣'),
            ),
        ],
      ),
      body: widget.controller.isEmpty
          ? const PopqEmptyView(
        icon: Icons.shopping_bag_outlined,
        title: '?λ컮援щ땲媛 鍮꾩뼱 ?덉뼱??',
        description: '?ㅽ넗?댁뿉???먰븯???곹뭹???댁븘蹂댁꽭??',
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
                                    label: const Text('??젣'),
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
                      ? '二쇰Ц 媛???щ?瑜??뺤씤?섍퀬 ?덉뼱??..'
                      : checking
                          ? '二쇰Ц 媛???щ? ?뺤씤 以?..'
                          : paused
                              ? '?꾩옱 二쇰Ц ?묒닔 以묒?'
                              : '${_won(widget.controller.totalAmount)} 쨌 二쇰Ц?섍린',
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
        ScaffoldMessenger.of(context).showTopSnackBar(
          const SnackBar(
            content: Text('?꾩옱 留ㅼ옣???좉퇋 二쇰Ц ?묒닔瑜??좎떆 以묒??덉뼱??'),
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
         * GoRouter??/sign-in 寃쎈줈瑜??ъ슜?섏? ?딆뒿?덈떎.
         *
         * 濡쒓렇???붾㈃???쇰컲 ?꾩껜 ?붾㈃ 紐⑤떖濡??닿린 ?뚮Ц??
         * 濡쒓렇???꾨즺 ??紐⑤떖??pop?섎㈃ 濡쒓렇???섏씠吏媛
         * GoRouter ?ㅻ줈媛湲?湲곕줉???⑥? ?딆뒿?덈떎.
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
       * 濡쒓렇??紐⑤떖???꾩쟾???쒓굅???꾩뿉留?
       * 寃곗젣 ?붾㈃???λ컮援щ땲 ?꾩뿉 push?⑸땲??
       *
       * ?붾㈃ 湲곕줉:
       * ?곹뭹/留ㅼ옣 ???λ컮援щ땲 ??寃곗젣
       */
      await context.push<void>(
        CustomerRoutes.checkout,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showTopSnackBar(
          SnackBar(
            content: Text(
              '二쇰Ц 媛???щ?瑜??뺤씤?섏? 紐삵뻽?댁슂. ?좎떆 ???ㅼ떆 ?쒕룄?댁＜?몄슂.\n$error',
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
                  '?꾩옱 二쇰Ц ?묒닔媛 ?좎떆 以묐떒?섏뿀?댁슂.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: PopqSpacing.xs),
                Text(
                  '?λ컮援щ땲???좎??⑸땲?? ?묒닔媛 ?ㅼ떆 ?쒖옉?섎㈃ 二쇰Ц?????덉뼱??',
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

  return '$buffer??;
}
