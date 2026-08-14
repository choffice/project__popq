import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';

void main() {
  group('AuthInputValidator', () {
    test('accepts complete email addresses', () {
      expect(AuthInputValidator.isValidEmail('user@example.com'), isTrue);
      expect(
        AuthInputValidator.isValidEmail('name.tag+1@sub.example.co.kr'),
        isTrue,
      );
    });

    test('rejects incomplete or malformed email addresses', () {
      for (final email in <String>[
        '@',
        'user@',
        '@example.com',
        'user@example',
        'user..name@example.com',
        'user@-example.com',
        'user@example.c',
      ]) {
        expect(AuthInputValidator.isValidEmail(email), isFalse, reason: email);
      }
    });
  });
}
