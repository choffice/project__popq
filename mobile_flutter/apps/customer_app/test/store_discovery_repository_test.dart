import 'package:flutter_test/flutter_test.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_repository.dart';

void main() {
  test('manual OPEN accepts orders regardless of guide hours', () {
    const store = CustomerStore(
      storeId: 1,
      storeType: 'LOCAL_STORE',
      name: '수동 영업 테스트',
      businessStatus: 'OPEN',
      openTime: '23:00:00',
      closeTime: '23:01:00',
      closedDays: <String>[
        'MONDAY',
        'TUESDAY',
        'WEDNESDAY',
        'THURSDAY',
        'FRIDAY',
        'SATURDAY',
        'SUNDAY',
      ],
      tags: <String>[],
    );

    expect(store.isOrderAccepting(), isTrue);
  });

  test('PRE_OPEN or disabled order accepting blocks orders', () {
    const preparing = CustomerStore(
      storeId: 1,
      storeType: 'LOCAL_STORE',
      name: '준비중 테스트',
      businessStatus: 'PRE_OPEN',
      tags: <String>[],
    );
    const paused = CustomerStore(
      storeId: 2,
      storeType: 'LOCAL_STORE',
      name: '주문 중지 테스트',
      businessStatus: 'OPEN',
      orderAcceptingEnabled: false,
      tags: <String>[],
    );

    expect(preparing.isOrderAccepting(), isFalse);
    expect(paused.isOrderAccepting(), isFalse);
  });
}
