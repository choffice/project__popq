import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_session.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _storageKey = _defaultStorageKey;

  static const _defaultStorageKey = 'popq.auth.session';

  final FlutterSecureStorage _storage;
  final String _storageKey;

  @override
  Future<AuthSession?> read() async {
    final value = await _storage.read(key: _storageKey);
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        await clear();
        return null;
      }
      return AuthSession.fromJson(Map<String, Object?>.from(decoded));
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) {
    return _storage.write(
      key: _storageKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _storageKey);
  }
}
