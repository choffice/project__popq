import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SellerStoreSelectionStore {
  Future<int?> read();

  Future<void> write(int storeId);

  Future<void> clear();
}

class SharedPreferencesSellerStoreSelectionStore
    implements SellerStoreSelectionStore {
  SharedPreferencesSellerStoreSelectionStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _selectedStoreKey = 'seller.selected_store_id.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<int?> read() => _preferences.getInt(_selectedStoreKey);

  @override
  Future<void> write(int storeId) {
    return _preferences.setInt(_selectedStoreKey, storeId);
  }

  @override
  Future<void> clear() {
    return _preferences.remove(_selectedStoreKey);
  }
}

class MemorySellerStoreSelectionStore implements SellerStoreSelectionStore {
  MemorySellerStoreSelectionStore([this._selectedStoreId]);

  int? _selectedStoreId;

  @override
  Future<int?> read() async => _selectedStoreId;

  @override
  Future<void> write(int storeId) async {
    _selectedStoreId = storeId;
  }

  @override
  Future<void> clear() async {
    _selectedStoreId = null;
  }
}
