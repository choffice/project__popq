import 'package:flutter/foundation.dart';
import 'package:popq_app_core/popq_app_core.dart';

import '../stores/seller_store_selection_controller.dart';
import 'seller_identity_repository.dart';

enum SellerBootstrapStatus { restoring, ready, failure }

class SellerBootstrapController extends ChangeNotifier {
  SellerBootstrapController({
    required this.sessionController,
    required this.storeSelectionController,
    required this.identityRepository,
  });

  final SessionController sessionController;
  final SellerStoreSelectionController storeSelectionController;
  final SellerIdentityRepository identityRepository;

  SellerBootstrapStatus status = SellerBootstrapStatus.restoring;
  Object? error;
  bool roleMismatch = false;

  Future<void> restore() async {
    status = SellerBootstrapStatus.restoring;
    error = null;
    roleMismatch = false;
    notifyListeners();

    await Future.wait([
      sessionController.restore(),
      storeSelectionController.restore(),
    ]);
    if (sessionController.status == SessionStatus.failure ||
        storeSelectionController.status == SellerStoreSelectionStatus.failure) {
      error =
          sessionController.restoreError ??
          storeSelectionController.restoreError;
      status = SellerBootstrapStatus.failure;
      notifyListeners();
      return;
    }

    if (sessionController.isSignedIn) {
      try {
        final identity = await identityRepository.getCurrent();
        if (!identity.isSeller) {
          roleMismatch = true;
          await _clearAccountState();
        }
      } on AuthenticationFailure {
        await _clearAccountState();
      } catch (caught) {
        error = caught;
        status = SellerBootstrapStatus.failure;
        notifyListeners();
        return;
      }
    }

    status = SellerBootstrapStatus.ready;
    notifyListeners();
  }

  void acknowledgeSellerSignIn() {
    roleMismatch = false;
    error = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clearAccountState();
    notifyListeners();
  }

  Future<void> _clearAccountState() async {
    await storeSelectionController.clear();
    await sessionController.signOut();
  }
}
