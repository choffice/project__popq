import 'package:flutter/foundation.dart';

import 'auth_session.dart';

enum SessionStatus { restoring, signedOut, signedIn, failure }

class SessionController extends ChangeNotifier {
  SessionController({
    required this.sessionStore,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SessionStore sessionStore;
  final DateTime Function() _now;

  SessionStatus _status = SessionStatus.restoring;
  AuthSession? _session;
  Object? _restoreError;

  SessionStatus get status => _status;
  AuthSession? get session => _session;
  Object? get restoreError => _restoreError;

  bool get isSignedIn => _status == SessionStatus.signedIn;

  String? get accessToken => _session?.accessToken;

  Future<void> restore() async {
    _status = SessionStatus.restoring;
    _restoreError = null;
    notifyListeners();

    try {
      final restored = await sessionStore.read();

      if (restored == null) {
        _session = null;
        _status = SessionStatus.signedOut;
      } else if (
      restored.isExpiredAt(_now().toUtc()) &&
          restored.refreshToken.isEmpty) {
        await sessionStore.clear();

        _session = null;
        _status = SessionStatus.signedOut;
      } else {
        _session = restored;
        _status = SessionStatus.signedIn;
      }
    } on Object catch (error) {
      _session = null;
      _restoreError = error;
      _status = SessionStatus.failure;
    }

    notifyListeners();
  }

  Future<void> save(AuthSession session) async {
    await sessionStore.write(session);

    _session = session;
    _restoreError = null;
    _status = SessionStatus.signedIn;

    notifyListeners();
  }

  Future<void> signOut() async {
    await sessionStore.clear();

    _session = null;
    _restoreError = null;
    _status = SessionStatus.signedOut;

    notifyListeners();
  }
}