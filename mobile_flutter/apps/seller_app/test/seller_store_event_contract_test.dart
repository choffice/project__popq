import 'package:flutter_test/flutter_test.dart';
import 'package:popq_seller_app/src/features/stores/seller_store_repository.dart';

void main() {
  test('SellerStore는 eventName이 없는 구버전 응답도 파싱한다', () {
    final SellerStore store = SellerStore.fromJson(<String, Object?>{
      'storeId': 1,
      'storeType': 'LOCAL_STORE',
      'name': '일반 매장',
      'status': 'ACTIVE',
      'businessStatus': 'PRE_OPEN',
      'myRole': 'OWNER',
    });

    expect(store.eventName, isNull);
  });

  test('메모리 저장소는 EVENT 행사명을 저장하고 LOCAL 전환 시 제거한다', () async {
    final MemorySellerStoreRepository repository = MemorySellerStoreRepository(
      stores: <SellerStore>[],
    );
    final DateTime start = DateTime(2026, 8, 14);
    final DateTime end = DateTime(2026, 8, 17);

    final SellerStore created = await repository.create(
      storeType: 'EVENT_COMMERCE',
      name: '행사 부스',
      eventName: '부산 커피 페스타',
      operationStartDate: start,
      operationEndDate: end,
    );
    expect(created.eventName, '부산 커피 페스타');

    final SellerStore changed = await repository.update(
      created.storeId,
      storeType: 'LOCAL_STORE',
      name: created.name,
      eventName: null,
      operationStartDate: null,
      operationEndDate: null,
    );
    expect(changed.eventName, isNull);
    expect(changed.operationStartDate, start);
    expect(changed.operationEndDate, end);
  });

  test('LOCAL 종료일은 명시적 제거만 null로 저장한다', () async {
    final DateTime start = DateTime(2026, 8, 14);
    final DateTime end = DateTime(2026, 12, 31);
    final MemorySellerStoreRepository repository = MemorySellerStoreRepository(
      stores: <SellerStore>[
        SellerStore(
          storeId: 7,
          storeType: 'LOCAL_STORE',
          name: '일반 매장',
          operationStartDate: start,
          operationEndDate: end,
          status: 'ACTIVE',
          businessStatus: 'PRE_OPEN',
          myRole: 'OWNER',
        ),
      ],
    );

    final SellerStore preserved = await repository.update(
      7,
      name: '일반 수정',
      operationStartDate: null,
      operationEndDate: null,
    );
    expect(preserved.operationStartDate, start);
    expect(preserved.operationEndDate, end);

    final SellerStore cleared = await repository.update(
      7,
      name: '종료일 제거',
      operationStartDate: null,
      operationEndDate: null,
      clearOperationEndDate: true,
    );
    expect(cleared.operationStartDate, start);
    expect(cleared.operationEndDate, isNull);
  });
}
