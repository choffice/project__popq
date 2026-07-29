import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';
import 'package:popq_seller_app/src/seller_app.dart';

void main() {
  testWidgets('seller shell opens order operations from navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const PopqSellerApp(environment: AppEnvironment.local()),
    );

    expect(find.text('빠른 운영'), findsOneWidget);

    await tester.tap(find.text('주문'));
    await tester.pumpAndSettle();

    expect(find.text('신규 주문'), findsWidgets);
    expect(find.textContaining('9.6'), findsOneWidget);
  });
}
