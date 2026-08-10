import 'package:flutter/material.dart';

import '../permissions/customer_permission_gateway.dart';
import 'store_discovery_repository.dart';

class KakaoStoreMapWeb extends StatelessWidget {
  const KakaoStoreMapWeb({
    required this.stores,
    required this.currentLocation,
    required this.searchCenter,
    super.key,
  });

  final List<CustomerStore> stores;
  final CustomerLocation? currentLocation;
  final CustomerLocation? searchCenter;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}