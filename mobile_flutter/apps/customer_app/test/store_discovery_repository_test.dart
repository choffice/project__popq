import 'package:flutter_test/flutter_test.dart';
import 'package:popq_customer_app/src/features/discovery/store_discovery_repository.dart';

void main() {
  test('LOCAL public 응답의 null eventName을 안전하게 파싱한다', () {
    final CustomerStore store = CustomerStore.fromJson(<String, Object?>{
      'storeId': 10,
      'storeType': 'LOCAL_STORE',
      'eventName': null,
      'name': '일반 매장',
      'businessStatus': 'PRE_OPEN',
    });

    expect(store.eventName, isNull);
  });

  test('EVENT public 응답의 eventName을 파싱한다', () {
    final CustomerStore store = CustomerStore.fromJson(<String, Object?>{
      'storeId': 11,
      'storeType': 'EVENT_COMMERCE',
      'eventName': '부산 바다 푸드 페스타',
      'name': '달빛 푸드트럭',
      'businessStatus': 'PRE_OPEN',
    });

    expect(store.eventName, '부산 바다 푸드 페스타');
  });

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
