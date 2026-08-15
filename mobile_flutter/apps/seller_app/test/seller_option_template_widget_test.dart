import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popq_seller_app/src/features/products/seller_product_editor.dart';
import 'package:popq_seller_app/src/features/products/seller_product_list_screen.dart';
import 'package:popq_seller_app/src/features/products/seller_product_repository.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_selection_controller.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_selection_store.dart';

void main() {
  const template = SellerStoreOptionTemplate(
    templateId: 10,
    storeId: 1,
    name: '온도',
    minSelect: 1,
    maxSelect: 1,
    required: true,
    version: 3,
    options: [
      SellerProductOption(name: 'HOT', additionalPrice: 0, displayOrder: 0),
      SellerProductOption(name: 'ICE', additionalPrice: 0, displayOrder: 1),
    ],
  );
  const product = SellerProduct(
    productId: 100,
    storeId: 1,
    categoryId: 1,
    categoryName: '음료',
    name: '카페라떼',
    basePrice: 4000,
    status: 'ACTIVE',
    soldOut: false,
    availableForQr: true,
    availableForCustomerApp: true,
    qrWebEnabled: true,
    customerAppEnabled: true,
  );
  const linkedGroup = SellerProductOptionGroup(
    optionGroupId: 20,
    templateId: 10,
    appliedTemplateVersion: 3,
    name: '온도',
    minSelect: 1,
    maxSelect: 1,
    required: true,
    displayOrder: 0,
    options: [
      SellerProductOption(name: 'HOT', additionalPrice: 0, displayOrder: 0),
      SellerProductOption(name: 'ICE', additionalPrice: 0, displayOrder: 1),
    ],
  );

  testWidgets('bulk apply appears only after actual option content changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MemorySellerProductRepository(
      products: const [product],
      optionGroups: const {
        100: [linkedGroup],
      },
      optionTemplates: const [template],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showSellerOptionEditor(
              context,
              product: product,
              groups: const [linkedGroup],
              templates: const [template],
              repository: repository,
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('동일 그룹에 변경사항 일괄 적용'), findsNothing);

    await tester.enterText(find.byKey(const Key('option-price-0-1')), '500');
    await tester.pump();
    expect(find.text('동일 그룹에 변경사항 일괄 적용'), findsOneWidget);

    await tester.ensureVisible(find.text('동일 그룹에 변경사항 일괄 적용'));
    await tester.tap(find.text('동일 그룹에 변경사항 일괄 적용'));
    await tester.pumpAndSettle();
    expect(find.textContaining('즉시 저장되며'), findsOneWidget);
    expect(find.textContaining('취소해도 되돌릴 수 없습니다'), findsOneWidget);
  });

  testWidgets('new product editor returns selected store templates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SellerProductDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showSellerProductEditor(
                context,
                categories: const [
                  SellerCategory(
                    storeId: 1,
                    categoryId: 1,
                    name: '음료',
                    displayOrder: 0,
                  ),
                ],
                optionTemplates: const [template],
              );
            },
            child: const Text('등록'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('product-name')), '카페라떼');
    await tester.enterText(find.byKey(const Key('product-price')), '4000');
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.optionGroups, hasLength(1));
    expect(result!.optionGroups.single.templateId, 10);
    expect(result!.optionGroups.single.options, hasLength(2));
  });

  testWidgets('template delete failure reports partial success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _DeleteFailRepository(
      products: const [product],
      optionGroups: const {
        100: [linkedGroup],
      },
      optionTemplates: const [template],
    );
    final selectionController = SellerStoreSelectionController(
      MemorySellerStoreSelectionStore(1),
    );
    await selectionController.restore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellerProductListScreen(
            repository: repository,
            selectionController: selectionController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-options-100')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('옵션 그룹 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공용 옵션도 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-options')));
    await tester.pumpAndSettle();

    expect(find.textContaining('현재 메뉴에서는 옵션을 제거했습니다'), findsOneWidget);
    expect(find.textContaining('공용 옵션은 유지했습니다'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}

class _DeleteFailRepository extends MemorySellerProductRepository {
  _DeleteFailRepository({
    required super.products,
    required super.optionGroups,
    required super.optionTemplates,
  });

  @override
  Future<void> deleteOptionTemplate(int storeId, int templateId) {
    throw StateError('template became used by another product');
  }
}
