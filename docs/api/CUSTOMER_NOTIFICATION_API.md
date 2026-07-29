# 고객 기기·알림 API

## 처리 원칙

- `/api/v1/customer/**`이므로 `CUSTOMER` Access Token이 필요하다.
- 알림은 주문 트랜잭션이 커밋된 뒤 `OrderRealtimeEvent`를 받아 생성한다.
- 회원 주문만 사용자 알림을 생성하며 QR 비회원 주문은 대상이 아니다.
- 푸시 알림은 상태 원본이 아니다. 앱은 알림 선택 후 주문 REST API를 다시 조회한다.
- `event_id` 유일성 제약으로 동일 주문 이벤트의 알림 중복 생성을 방지한다.

## 기기 토큰

| Method | Path | 설명 |
|---|---|---|
| POST | `/api/v1/customer/devices` | 기기 토큰 등록 또는 현재 사용자에게 재귀속 |
| GET | `/api/v1/customer/devices` | 내 등록 기기 목록 |
| DELETE | `/api/v1/customer/devices/{deviceId}` | 내 기기 등록 해제 |

등록 요청:

```json
{
  "token": "fcm-registration-token",
  "platform": "ANDROID"
}
```

`platform`은 `ANDROID` 또는 `IOS`다. 토큰은 전체 시스템에서 유일하며 동일 토큰을 다시 등록해도 기기 행을 중복 생성하지 않는다. 목록 응답에는 원본 토큰을 노출하지 않는다.

## 알림

| Method | Path | 설명 |
|---|---|---|
| GET | `/api/v1/customer/notifications` | 내 알림 전체 목록 |
| GET | `/api/v1/customer/notifications?unreadOnly=true` | 읽지 않은 알림 목록 |
| GET | `/api/v1/customer/notifications/unread-count` | 읽지 않은 알림 개수 |
| POST | `/api/v1/customer/notifications/{notificationId}/read` | 내 알림 읽음 처리 |

주문 알림 응답 예시:

```json
{
  "notificationId": 31,
  "type": "ORDER_STATUS",
  "targetType": "ORDER",
  "targetId": "01JORDERPUBLICID",
  "title": "주문 상품이 준비됐어요",
  "message": "스토어에서 상품을 수령해 주세요.",
  "deepLink": "/orders/01JORDERPUBLICID",
  "read": false,
  "occurredAt": "2026-07-29T08:30:00Z"
}
```

읽음 처리와 기기 해제는 소유자만 가능하다. 다른 사용자의 식별자를 요청하면 각각 `NOTIFICATION_NOT_FOUND`, `PUSH_DEVICE_NOT_FOUND`를 반환한다.

## Firebase 연결 경계

백엔드는 `PushNotificationGateway` 인터페이스까지 구현했다. Firebase 프로젝트가 설정되지 않은 현재 환경에서는 `LoggingPushNotificationGateway`가 실제 송신을 생략한다.

Firebase 연결 시 필요한 후속 작업:

1. 서버에 Firebase Admin 서비스 계정과 환경별 프로젝트 ID 주입
2. `PushNotificationGateway`의 Firebase 구현체 활성화
3. Flutter 앱에 `google-services.json`과 `GoogleService-Info.plist` 추가
4. Firebase Messaging 토큰을 로그인·갱신 시 기기 등록 API로 전송
5. 포그라운드·백그라운드·종료 상태 메시지 선택을 주문 딥링크로 전달

테이블은 Flyway `V6__create_notification_tables.sql`에서 생성한다.
