import 'package:flutter/foundation.dart';

import 'seller_store_selection_store.dart';

enum SellerStoreSelectionStatus { restoring, ready, failure }

class SellerStoreSelectionController extends ChangeNotifier {
  SellerStoreSelectionController(this._store);

  final SellerStoreSelectionStore _store;

  SellerStoreSelectionStatus status = SellerStoreSelectionStatus.restoring;
  int? selectedStoreId;
  Object? restoreError;

  bool get hasSelection => selectedStoreId != null;

  Future<void> restore() async {
    status = SellerStoreSelectionStatus.restoring;
    restoreError = null;
    notifyListeners();
    try {
      selectedStoreId = await _store.read();
      status = SellerStoreSelectionStatus.ready;
    } catch (error) {
      selectedStoreId = null;
      restoreError = error;
      status = SellerStoreSelectionStatus.failure;
    }
    notifyListeners();
  }

  Future<void> select(int storeId) async {
    await _store.write(storeId);
    selectedStoreId = storeId;
    status = SellerStoreSelectionStatus.ready;
    restoreError = null;
    notifyListeners();
  }

  Future<void> clear() async {
    await _store.clear();
    selectedStoreId = null;
    status = SellerStoreSelectionStatus.ready;
    restoreError = null;
    notifyListeners();
  }
}
