import 'package:flutter_test/flutter_test.dart';
import 'package:popq_app_core/popq_app_core.dart';

void main() {
  group('PopqOrderRealtimeEvent', () {
    test('로그인 고객 주문 상태 이벤트를 파싱한다', () {
      final event = PopqOrderRealtimeEvent.fromJson(<String, Object?>{
        'eventId': 'event-1',
        'eventType': 'ORDER_PREPARING',
        'orderPublicId': 'ORDER-20260807-0001',
        'storeId': 7,
        'guestSessionId': null,
        'userId': 15,
        'previousStatus': 'ACCEPTED',
        'currentStatus': 'PREPARING',
        'occurredAt': '2026-08-07T04:10:20Z',
        'version': 3,
      });

      expect(event.eventType, PopqOrderRealtimeEventType.preparing);
      expect(event.orderPublicId, 'ORDER-20260807-0001');
      expect(event.storeId, 7);
      expect(event.userId, 15);
      expect(event.guestSessionId, isNull);
      expect(event.previousStatus, 'ACCEPTED');
      expect(event.currentStatus, 'PREPARING');
      expect(event.version, 3);
      expect(event.isSignedInCustomerOrder, isTrue);
      expect(event.isGuestOrder, isFalse);
    });

    test('version 비교로 중복과 누락 이벤트를 구분한다', () {
      final event = PopqOrderRealtimeEvent.fromJson(<String, Object?>{
        'eventId': 'event-2',
        'eventType': 'ORDER_READY',
        'orderPublicId': 'ORDER-20260807-0002',
        'storeId': 9,
        'guestSessionId': null,
        'userId': 21,
        'previousStatus': 'PREPARING',
        'currentStatus': 'READY',
        'occurredAt': '2026-08-07T04:11:20Z',
        'version': 5,
      });

      expect(event.isDuplicateOrOlderThan(5), isTrue);
      expect(event.isDuplicateOrOlderThan(6), isTrue);
      expect(event.isDuplicateOrOlderThan(4), isFalse);
      expect(event.isNextVersionAfter(4), isTrue);
      expect(event.hasVersionGapAfter(3), isTrue);
      expect(event.hasVersionGapAfter(4), isFalse);
    });

    test('지원하지 않는 주문 이벤트 유형은 거부한다', () {
      expect(
        () => PopqOrderRealtimeEvent.fromJson(<String, Object?>{
          'eventId': 'event-3',
          'eventType': 'ORDER_UNKNOWN',
          'orderPublicId': 'ORDER-20260807-0003',
          'storeId': 1,
          'guestSessionId': null,
          'userId': 1,
          'previousStatus': null,
          'currentStatus': 'UNKNOWN',
          'occurredAt': '2026-08-07T04:12:20Z',
          'version': 1,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
