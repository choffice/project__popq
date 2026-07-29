import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';

void main() {
  test('local environment uses the Android emulator backend address', () {
    const environment = AppEnvironment.local();

    expect(environment.flavor, AppFlavor.development);
    expect(environment.apiBaseUrl, 'http://10.0.2.2:8082');
    expect(environment.isProduction, isFalse);
  });

  test('API envelope decodes success data', () {
    final envelope = ApiEnvelope<int>.fromJson({
      'success': true,
      'data': 7,
      'error': null,
    }, (value) => value! as int);

    expect(envelope.success, isTrue);
    expect(envelope.data, 7);
    expect(envelope.error, isNull);
  });

  test('auth session expiration uses the supplied clock', () {
    final now = DateTime.utc(2026, 7, 29, 12);
    final session = AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAt: now.add(const Duration(minutes: 5)),
    );

    expect(session.isExpiredAt(now), isFalse);
    expect(session.isExpiredAt(now.add(const Duration(minutes: 6))), isTrue);
  });
}
