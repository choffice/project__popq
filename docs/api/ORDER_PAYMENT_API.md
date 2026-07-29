# 주문·결제 API 계약

## 공통 원칙

- QR 게스트 API는 `POPQ_GUEST_SESSION` HttpOnly 쿠키가 필요하다.
- 서버가 상품과 옵션 가격을 다시 조회해 최종 금액을 계산한다.
- 주문 생성과 결제 승인은 각각 별도의 `idempotencyKey`를 사용한다.
- 같은 키와 같은 요청의 재전송은 기존 결과를 반환한다.
- 같은 키에 다른 요청을 보내면 `409 IDEMPOTENCY_CONFLICT`를 반환한다.
- 결제 가능 기본 시간은 주문 생성 후 15분이며 `POPQ_ORDER_PAYMENT_DEADLINE`으로 변경한다.

## 주문 상태

```text
CREATED ──결제 승인──> PLACED ──판매자 접수──> ACCEPTED
   │                     │                       │
   └──시간 만료──> EXPIRED ├──고객 취소──> CANCELED └──> PREPARING ──> READY ──> COMPLETED
                         └──판매자 거절──> REJECTED
```

`PLACED` 주문의 고객 취소와 판매자 거절은 TestPaymentProvider 결제 취소 및 환불 이력을 함께 생성한다.

## 게스트 주문 생성

`POST /api/v1/qr/orders`

```json
{
  "idempotencyKey": "order_550e8400-e29b-41d4-a716-446655440000",
  "orderType": "TAKEOUT",
  "items": [
    {
      "productId": 10,
      "quantity": 2,
      "optionIds": [31]
    }
  ]
}
```

클라이언트가 전송한 금액은 사용하지 않는다. 응답의 `unitPrice`, `optionPrice`, `itemTotalPrice`, `totalAmount`가 서버 확정값이다.

## 결제 승인

`POST /api/v1/qr/orders/{orderPublicId}/payments`

```json
{
  "idempotencyKey": "payment_550e8400-e29b-41d4-a716-446655440000",
  "simulateFailure": false
}
```

개발용 `TEST` 공급자만 연결되어 있다. `simulateFailure=true`는 실패 이력과 `402 PAYMENT_FAILED` 응답을 검증하는 테스트 전용 입력이다.

## 게스트 주문 조회·취소

- `GET /api/v1/qr/orders/{orderPublicId}`
- `GET /api/v1/qr/orders/{orderPublicId}/sync?knownVersion={version}`
- `POST /api/v1/qr/orders/{orderPublicId}/cancel`

취소 요청:

```json
{
  "reason": "고객 변심"
}
```

게스트 세션이 소유한 주문만 조회·취소할 수 있으며 `PLACED` 상태에서만 고객 취소가 가능하다.

`sync` 응답의 `serverVersion`이 클라이언트의 `knownVersion`과 같으면 `refreshRequired=false`이며 `order`를 생략한다. 버전이 다르면 `refreshRequired=true`와 최신 전체 주문을 반환한다.

## 회원 소비자 주문

Bearer Access Token과 `CUSTOMER` 역할이 필요하다.

- `POST /api/v1/customer/orders/stores/{storeId}` — 주문 생성
- `GET /api/v1/customer/orders` — 내 주문 최신순 목록
- `GET /api/v1/customer/orders/{orderPublicId}` — 내 주문 상세
- `GET /api/v1/customer/orders/{orderPublicId}/sync?knownVersion={version}` — 상태 복구
- `POST /api/v1/customer/orders/{orderPublicId}/payments` — 결제 승인
- `POST /api/v1/customer/orders/{orderPublicId}/cancel` — 결제된 주문 취소

주문 생성·결제 본문은 게스트 계약과 같은 구조다. 회원 주문은 `orders.user_id`로 소유권을 고정하며 다른 회원의 주문 상세은 존재 여부를 노출하지 않고 `404 ORDER_NOT_FOUND`로 응답한다.

클라이언트는 네트워크 응답 유실 시에도 주문과 결제에 사용한 멱등성 키를 각각 유지해야 한다. 주문 생성은 같은 회원·스토어·요청 해시일 때 기존 주문을 반환하며, 결제도 같은 주문과 키의 성공 결과를 반환한다.

## 판매자 주문 API

- `GET /api/v1/seller/stores/{storeId}/orders?status=PLACED`
- `GET /api/v1/seller/stores/{storeId}/orders/{orderPublicId}`
- `GET /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/sync?knownVersion={version}`
- `POST .../{orderPublicId}/accept`
- `POST .../{orderPublicId}/reject`
- `POST .../{orderPublicId}/prepare`
- `POST .../{orderPublicId}/ready`
- `POST .../{orderPublicId}/complete`

상태 변경 본문은 공통으로 `{"reason":"..."}` 형식이며 생략할 때는 빈 객체 `{}`를 보낸다. OWNER, MANAGER, STAFF만 자신의 스토어 주문을 처리할 수 있다.

## 판매자 결제·환불 운영

- `GET /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/payment`
- `POST /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/refunds`

결제 요약과 기존 환불 이력은 OWNER, MANAGER, STAFF가 조회할 수 있다. 실제 환불 실행은 OWNER와 MANAGER만 가능하다.

MVP의 수동 환불은 `COMPLETED` 주문의 남은 승인 금액 전액만 지원한다. 진행 중 주문은 기존 주문 거절 흐름을 사용하고 부분 환불은 후속 범위로 둔다.

```json
{
  "amount": 12500,
  "reason": "고객 요청 전액 환불"
}
```

성공하면 결제 상태가 `REFUNDED`가 되고 성공한 환불 이력이 추가된다. 같은 결제의 중복 환불은 `REFUND_NOT_ALLOWED`, 승인 금액과 다른 금액은 `INVALID_REFUND_AMOUNT`로 차단한다. 전액 환불된 완료 주문은 순매출 집계에서 제외된다.

## 주요 오류 코드

| HTTP | 코드 | 의미 |
|---|---|---|
| 400 | `OPTION_NOT_FOUND` | 옵션이 없거나 해당 상품의 옵션이 아님 |
| 400 | `INVALID_OPTION_SELECTION` | 옵션 그룹의 최소·최대 선택 조건 위반 |
| 402 | `PAYMENT_FAILED` | 공급자 결제 승인 실패 |
| 403 | `ORDER_ACCESS_DENIED` | 게스트 또는 회원이 소유하지 않은 주문 작업 |
| 409 | `PRODUCT_UNAVAILABLE` | 품절 또는 판매 시간·채널 제한 |
| 409 | `IDEMPOTENCY_CONFLICT` | 멱등성 키 재사용 충돌 |
| 409 | `INVALID_ORDER_STATUS` | 허용되지 않은 상태 전이 |
| 409 | `ORDER_CANNOT_CANCEL` | 취소 가능한 상태가 아님 |
| 409 | `REFUND_NOT_ALLOWED` | 완료 주문이 아니거나 이미 환불된 결제 |
| 400 | `INVALID_REFUND_AMOUNT` | MVP 전액 환불 금액과 불일치 |
| 409 | `ORDER_EXPIRED` | 결제 가능 시간 만료 |
