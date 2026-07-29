import 'package:flutter/foundation.dart';

import '../permissions/customer_permission_gateway.dart';
import 'store_discovery_repository.dart';

enum DiscoveryStatus { loading, data, empty, failure }

class StoreDiscoveryController extends ChangeNotifier {
  StoreDiscoveryController({
    required this._repository,
    required this._permissionGateway,
  });

  final StoreDiscoveryRepository _repository;
  final CustomerPermissionGateway _permissionGateway;

  DiscoveryStatus status = DiscoveryStatus.loading;
  List<CustomerStore> stores = const [];
  String? selectedTag;
  CustomerLocation? location;
  Object? error;

  Future<void> search({String? query}) async {
    status = DiscoveryStatus.loading;
    error = null;
    notifyListeners();
    try {
      stores = await _repository.search(
        query: query,
        tag: selectedTag,
        location: location,
        radiusKm: location == null ? null : 10,
      );
      status = stores.isEmpty ? DiscoveryStatus.empty : DiscoveryStatus.data;
    } catch (caught) {
      error = caught;
      status = DiscoveryStatus.failure;
    }
    notifyListeners();
  }

  Future<PermissionDecision> useCurrentLocation({String? query}) async {
    final result = await _permissionGateway.requestLocation();
    if (result.location != null) {
      location = result.location;
      await search(query: query);
    }
    return result.decision;
  }

  Future<void> selectTag(String? value, {String? query}) async {
    selectedTag = selectedTag == value ? null : value;
    await search(query: query);
  }
}
