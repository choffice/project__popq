import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/customer_router.dart';
import '../common/customer_count_badge.dart';
import 'cart_controller.dart';

class CustomerCartAction extends StatelessWidget {
  const CustomerCartAction({
    required this.controller,
    super.key,
  });

  final CartController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomerCountBadge(
          count: controller.itemCount,
          child: IconButton(
            tooltip: '장바구니',
            onPressed: () => context.push(CustomerRoutes.cart),
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
        );
      },
    );
  }
}
