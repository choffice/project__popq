import 'package:flutter/material.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_design_system/popq_design_system.dart';

import 'seller_root_screen.dart';

class PopqSellerApp extends StatelessWidget {
  const PopqSellerApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POPQ Seller',
      debugShowCheckedModeBanner: !environment.isProduction,
      theme: PopqTheme.light(),
      home: const SellerRootScreen(),
    );
  }
}
