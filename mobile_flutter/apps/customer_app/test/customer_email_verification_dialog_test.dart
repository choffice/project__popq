import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_customer_app/src/features/auth/customer_sign_up_screen.dart';

void main() {
  testWidgets('shows verification dialog after sending email code', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerSignUpScreen(
          onSignUp:
              ({
                required String email,
                required String password,
                required String name,
                required String phone,
                required String emailVerificationToken,
              }) async {},
          onSendEmailVerificationCode: (_) async {},
          onVerifyEmailCode: (_, code) async {
            expect(code, '123456');
            return 'verification-token';
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('sign-up-email')),
      'customer@example.com',
    );
    await tester.tap(find.byKey(const Key('sign-up-send-email-code')));
    await tester.pumpAndSettle();

    expect(find.text('이메일 인증'), findsOneWidget);
    expect(find.byKey(const Key('sign-up-email-code-dialog')), findsOneWidget);
    expect(find.byKey(const Key('sign-up-name')), findsOneWidget);
    expect(find.byKey(const Key('sign-up-password')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('sign-up-email-code-dialog')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('sign-up-verify-email-code-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('이메일 인증'), findsNothing);
    expect(find.text('이메일 인증 완료'), findsOneWidget);
    expect(find.byKey(const Key('sign-up-name')), findsOneWidget);
    expect(find.byKey(const Key('sign-up-password')), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
