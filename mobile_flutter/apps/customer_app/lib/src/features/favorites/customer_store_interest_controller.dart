import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../profile/customer_engagement_repository.dart';

enum CustomerStoreInterestStatus {
  initial,
  loading,
  ready,
  failure,
}

enum CustomerStoreInterestToggleResult {
  added,
  removed,
  signInRequired,
  failure,
}

class CustomerStoreInterestController extends ChangeNotifier {
  CustomerStoreInterestController({
    required CustomerEngagementRepository repository,
    required SessionController sessionController,
  }) : _repository = repository,
        _sessionController = sessionController,
        _lastSignedIn = sessionController.isSignedIn {
    _sessionController.addListener(
      _handleSessionChanged,
    );
  }

  final CustomerEngagementRepository _repository;
  final SessionController _sessionController;

  final Set<int> _interestedStoreIds = <int>{};
  final Set<int> _updatingStoreIds = <int>{};

  CustomerStoreInterestStatus _status =
      CustomerStoreInterestStatus.initial;

  Object? _error;

  bool _lastSignedIn;
  bool _disposed = false;
  int _requestVersion = 0;

  CustomerStoreInterestStatus get status => _status;

  Object? get error => _error;

  bool get isSignedIn => _sessionController.isSignedIn;

  bool get isLoading =>
      _status == CustomerStoreInterestStatus.loading;

  Set<int> get interestedStoreIds =>
      Set.unmodifiable(_interestedStoreIds);

  bool isInterested(int storeId) {
    return _interestedStoreIds.contains(storeId);
  }

  bool isUpdating(int storeId) {
    return _updatingStoreIds.contains(storeId);
  }

  Future<void> load() async {
    final requestVersion = ++_requestVersion;

    if (!_sessionController.isSignedIn) {
      _interestedStoreIds.clear();
      _updatingStoreIds.clear();
      _error = null;
      _status = CustomerStoreInterestStatus.ready;
      _notifySafely();
      return;
    }

    _status = CustomerStoreInterestStatus.loading;
    _error = null;
    _notifySafely();

    try {
      final stores = await _repository.findInterests();

      if (_disposed ||
          requestVersion != _requestVersion) {
        return;
      }

      _interestedStoreIds
        ..clear()
        ..addAll(
          stores.map(
                (store) => store.storeId,
          ),
        );

      _status = CustomerStoreInterestStatus.ready;
      _error = null;
      _notifySafely();
    } catch (error) {
      if (_disposed ||
          requestVersion != _requestVersion) {
        return;
      }

      _status = CustomerStoreInterestStatus.failure;
      _error = error;
      _notifySafely();
    }
  }

  Future<CustomerStoreInterestToggleResult> toggle(
      int storeId,
      ) async {
    if (!_sessionController.isSignedIn) {
      return CustomerStoreInterestToggleResult
          .signInRequired;
    }

    if (_updatingStoreIds.contains(storeId)) {
      return _interestedStoreIds.contains(storeId)
          ? CustomerStoreInterestToggleResult.added
          : CustomerStoreInterestToggleResult.removed;
    }

    final wasInterested =
    _interestedStoreIds.contains(storeId);

    _updatingStoreIds.add(storeId);

    if (wasInterested) {
      _interestedStoreIds.remove(storeId);
    } else {
      _interestedStoreIds.add(storeId);
    }

    _notifySafely();

    try {
      final interested = wasInterested
          ? await _repository.removeInterest(storeId)
          : await _repository.addInterest(storeId);

      if (_disposed) {
        return interested
            ? CustomerStoreInterestToggleResult.added
            : CustomerStoreInterestToggleResult.removed;
      }

      if (interested) {
        _interestedStoreIds.add(storeId);
      } else {
        _interestedStoreIds.remove(storeId);
      }

      _error = null;
      _notifySafely();

      return interested
          ? CustomerStoreInterestToggleResult.added
          : CustomerStoreInterestToggleResult.removed;
    } catch (error) {
      if (!_disposed) {
        if (wasInterested) {
          _interestedStoreIds.add(storeId);
        } else {
          _interestedStoreIds.remove(storeId);
        }

        _error = error;
        _notifySafely();
      }

      return CustomerStoreInterestToggleResult.failure;
    } finally {
      if (!_disposed) {
        _updatingStoreIds.remove(storeId);
        _notifySafely();
      }
    }
  }

  void _handleSessionChanged() {
    final signedIn =
        _sessionController.isSignedIn;

    if (_lastSignedIn == signedIn) {
      return;
    }

    _lastSignedIn = signedIn;

    if (signedIn) {
      unawaited(load());
      return;
    }

    _requestVersion++;
    _interestedStoreIds.clear();
    _updatingStoreIds.clear();
    _status = CustomerStoreInterestStatus.ready;
    _error = null;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;

    _sessionController.removeListener(
      _handleSessionChanged,
    );

    super.dispose();
  }
}