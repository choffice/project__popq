import 'package:flutter/material.dart';

import '../permissions/customer_permission_gateway.dart';
import 'store_discovery_repository.dart';
import 'kakao_store_map.dart';

class KakaoStoreMapWeb extends StatelessWidget {
  const KakaoStoreMapWeb({
    this.controller,
    required this.stores,
    required this.currentLocation,
    required this.searchCenter,
    required this.onStoreSelected,
    required this.selectedStoreId,
    required this.favoriteStoreIds,
    required this.onViewportIdle,
    super.key,
  });

  final KakaoStoreMapController? controller;

  final List<CustomerStore> stores;
  final CustomerLocation? currentLocation;
  final CustomerLocation? searchCenter;
  final ValueChanged<CustomerStore> onStoreSelected;
  final int? selectedStoreId;
  final Set<int> favoriteStoreIds;
  final ValueChanged<KakaoMapViewport>? onViewportIdle;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}