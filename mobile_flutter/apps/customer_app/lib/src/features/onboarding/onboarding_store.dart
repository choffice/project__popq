import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingStore {
  Future<bool> isComplete();

  Future<void> markComplete();
}

class SharedPreferencesOnboardingStore implements OnboardingStore {
  SharedPreferencesOnboardingStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _completionKey = 'customer_onboarding_complete_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> isComplete() async {
    return await _preferences.getBool(_completionKey) ?? false;
  }

  @override
  Future<void> markComplete() {
    return _preferences.setBool(_completionKey, true);
  }
}

class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore() : _complete = false;

  MemoryOnboardingStore.complete() : _complete = true;

  bool _complete;

  @override
  Future<bool> isComplete() async => _complete;

  @override
  Future<void> markComplete() async {
    _complete = true;
  }
}
