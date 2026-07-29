import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_design_system/popq_design_system.dart';

void main() {
  testWidgets('feature card renders the shared visual contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PopqTheme.light(),
        home: const Scaffold(
          body: PopqFeatureCard(
            icon: Icons.storefront_outlined,
            title: '내 주변 스토어',
            description: '현재 위치에서 가까운 매장을 찾아보세요.',
          ),
        ),
      ),
    );

    expect(find.text('내 주변 스토어'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(PopqTheme.light().colorScheme.primary, PopqPalette.forest);
  });

  testWidgets('error view exposes its retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PopqTheme.light(),
        home: PopqErrorView(
          message: '연결을 확인해 주세요.',
          onRetry: () => retried = true,
        ),
      ),
    );

    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });
}
