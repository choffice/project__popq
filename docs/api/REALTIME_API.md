# 실시간 주문 API 계약

## 연결과 인증

STOMP endpoint는 `/ws`다.

### 판매자

판매자 React 클라이언트는 STOMP `CONNECT` frame에 다음 헤더를 전달한다.

```text
Authorization: Bearer {accessToken}
```

연결 후 자신의 스토어만 구독한다.

```text
/topic/stores/{storeId}/orders
```

### QR 게스트

게스트는 QR 세션 생성 시 발급된 `POPQ_GUEST_SESSION` HttpOnly 쿠키를 사용한다. 브라우저가 `/ws` handshake에 쿠키를 자동으로 포함하므로 JavaScript에서 세션 토큰을 읽거나 STOMP 헤더에 복사하지 않는다.

연결 후 자신이 소유한 주문만 구독한다.

```text
/user/queue/orders/{orderPublicId}
```

서버는 `CONNECT` 인증과 별개로 `SUBSCRIBE`마다 StoreMember 또는 GuestSession 주문 소유권을 다시 검사한다. 클라이언트의 STOMP `SEND`는 허용하지 않는다.

## 이벤트 payload

```json
{
  "eventId": "7ed27d54-a477-4d3b-8c98-677ab7501de1",
  "eventType": "ORDER_ACCEPTED",
  "orderPublicId": "12ef59fb-9b4d-4b82-908d-5cb306860dc9",
  "storeId": 10,
  "guestSessionId": 21,
  "previousStatus": "PLACED",
  "currentStatus": "ACCEPTED",
  "occurredAt": "2026-07-29T03:00:00Z",
  "version": 2
}
```

현재 발행되는 이벤트:

- `ORDER_PLACED`
- `ORDER_ACCEPTED`
- `ORDER_PREPARING`
- `ORDER_READY`
- `ORDER_COMPLETED`
- `ORDER_CANCELED`
- `ORDER_REJECTED`
- `ORDER_EXPIRED`

이벤트는 주문 트랜잭션이 커밋된 이후에만 전송된다. `eventId`는 연결 중 중복 제거에 사용하고, 최종 정합성 판단에는 `version`을 사용한다.

## 클라이언트 적용 규칙

1. `eventId`를 이미 처리했다면 무시한다.
2. 이벤트 `version <= localVersion`이면 중복 또는 역순 이벤트이므로 무시한다.
3. 이벤트 `version == localVersion + 1`이면 상태를 적용한다.
4. 이벤트 버전이 두 단계 이상 앞서면 REST `sync`를 호출한다.
5. WebSocket 재연결 직후에는 이벤트 유실 여부와 관계없이 REST `sync`를 호출한다.

게스트:

```text
GET /api/v1/qr/orders/{orderPublicId}/sync?knownVersion={localVersion}
```

판매자:

```text
GET /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/sync?knownVersion={localVersion}
```

동기화 응답:

```json
{
  "success": true,
  "data": {
    "refreshRequired": true,
    "serverVersion": 4,
    "order": {
      "orderPublicId": "12ef59fb-9b4d-4b82-908d-5cb306860dc9",
      "status": "PREPARING",
      "version": 4
    }
  }
}
```

버전이 같으면 `refreshRequired=false`이고 `order`는 `null`이다.

## 개발 환경과 운영 확장

허용 Origin은 `POPQ_REALTIME_ALLOWED_ORIGINS`의 쉼표 구분 목록으로 설정한다.

현재 Spring simple broker는 단일 백엔드 인스턴스용이며 메시지를 영구 보관하지 않는다. 따라서 MySQL 주문 데이터와 REST 동기화 API가 항상 최종 원본이다. 백엔드를 여러 인스턴스로 확장할 때는 RabbitMQ 등의 STOMP broker relay로 전환한다.
