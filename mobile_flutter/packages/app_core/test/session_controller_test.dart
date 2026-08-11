import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';

void main() {
  test('session controller restores a valid session', () async {
    final now = DateTime.utc(2026, 7, 29, 12);

    final controller = SessionController(
      sessionStore: MemorySessionStore(
        AuthSession(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      ),
      now: () => now,
    );

    await controller.restore();

    expect(controller.status, SessionStatus.signedIn);
    expect(controller.accessToken, 'access');
  });

  test(
    'session controller keeps an expired access token session '
        'when a refresh token exists',
        () async {
      final now = DateTime.utc(2026, 7, 29, 12);

      final store = MemorySessionStore(
        AuthSession(
          accessToken: 'expired',
          refreshToken: 'refresh',
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
      );

      final controller = SessionController(
        sessionStore: store,
        now: () => now,
      );

      await controller.restore();

      expect(controller.status, SessionStatus.signedIn);
      expect(controller.accessToken, 'expired');

      final restored = await store.read();

      expect(restored, isNotNull);
      expect(restored!.refreshToken, 'refresh');
    },
  );

  test(
    'session controller clears an expired session '
        'when no refresh token exists',
        () async {
      final now = DateTime.utc(2026, 7, 29, 12);

      final store = MemorySessionStore(
        AuthSession(
          accessToken: 'expired',
          refreshToken: '',
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
      );

      final controller = SessionController(
        sessionStore: store,
        now: () => now,
      );

      await controller.restore();

      expect(controller.status, SessionStatus.signedOut);
      expect(await store.read(), isNull);
    },
  );

  test(
    'session controller exposes restore failure without hanging',
        () async {
      final controller = SessionController(
        sessionStore: _FailingSessionStore(),
      );

      await controller.restore();

      expect(controller.status, SessionStatus.failure);
      expect(controller.restoreError, isA<StateError>());
    },
  );
}

class _FailingSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async {
    throw StateError('secure storage unavailable');
  }

  @override
  Future<void> write(AuthSession session) async {}
}