import 'package:flutter/foundation.dart';

import 'onboarding_store.dart';

enum OnboardingStatus { restoring, incomplete, complete, failure }

class OnboardingController extends ChangeNotifier {
  OnboardingController(this._store);

  final OnboardingStore _store;

  OnboardingStatus status = OnboardingStatus.restoring;

  bool get isComplete => status == OnboardingStatus.complete;

  Future<void> restore() async {
    status = OnboardingStatus.restoring;
    notifyListeners();
    try {
      status = await _store.isComplete()
          ? OnboardingStatus.complete
          : OnboardingStatus.incomplete;
    } catch (_) {
      status = OnboardingStatus.failure;
    }
    notifyListeners();
  }

  Future<void> complete() async {
    await _store.markComplete();
    status = OnboardingStatus.complete;
    notifyListeners();
  }
}
