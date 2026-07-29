# 고객 관심·리뷰·마이페이지 API

## 인증과 공통 규칙

- `/api/v1/customer/**`는 `CUSTOMER` Access Token이 필요하다.
- `/api/v1/public/stores/{storeId}/reviews`는 인증 없이 조회할 수 있다.
- 응답은 공통 `ApiResponse` envelope의 `data`에 담긴다.
- 관심 등록·해제는 같은 요청을 반복해도 최종 상태가 유지된다.

## 관심 스토어

| Method | Path | 설명 |
|---|---|---|
| GET | `/api/v1/customer/store-interests` | 내 관심 스토어 목록 |
| GET | `/api/v1/customer/store-interests/{storeId}` | 관심 여부 |
| POST | `/api/v1/customer/store-interests/{storeId}` | 관심 등록 |
| DELETE | `/api/v1/customer/store-interests/{storeId}` | 관심 해제 |

관심 등록은 공개 가능한 영업 중 스토어만 허용한다. 데이터베이스의 `(user_id, store_id)` 유일성 제약으로 중복 관계를 방지한다.

관심 상태 응답:

```json
{
  "storeId": 12,
  "interested": true
}
```

## 리뷰

| Method | Path | 설명 |
|---|---|---|
| GET | `/api/v1/customer/reviews` | 삭제 이력을 포함한 내 리뷰 목록 |
| POST | `/api/v1/customer/reviews/orders/{orderPublicId}` | 완료 주문 리뷰 작성 |
| PUT | `/api/v1/customer/reviews/{reviewId}` | 내 활성 리뷰 수정 |
| DELETE | `/api/v1/customer/reviews/{reviewId}` | 내 활성 리뷰 소프트 삭제 |
| GET | `/api/v1/public/stores/{storeId}/reviews` | 스토어의 활성 공개 리뷰 |

작성·수정 요청:

```json
{
  "rating": 5,
  "content": "다시 주문할게요."
}
```

리뷰 규칙:

- 별점은 1~5이고 내용은 최대 1,000자다.
- 로그인 고객 본인의 `COMPLETED` 주문에만 작성할 수 있다.
- 주문당 리뷰는 최대 1개다.
- 수정·삭제는 작성자만 가능하다.
- 삭제 시 상태를 `DELETED`로 바꾸고 내용을 제거한다. 공개 목록과 활성 리뷰 집계에서는 제외한다.
- 리뷰 이미지는 파일 저장소와 검수 정책 확정 전까지 지원하지 않는다.

주요 오류:

| HTTP | Code | 조건 |
|---|---|---|
| 404 | `ORDER_NOT_FOUND` | 본인 주문을 찾을 수 없음 |
| 404 | `REVIEW_NOT_FOUND` | 리뷰가 없거나 작성자가 아님 |
| 409 | `REVIEW_NOT_ALLOWED` | 주문이 완료되지 않음 |
| 409 | `REVIEW_ALREADY_EXISTS` | 해당 주문에 리뷰가 이미 존재 |

## 마이페이지

`GET /api/v1/customer/profile`은 사용자 기본 정보와 다음 집계를 반환한다.

```json
{
  "user": {
    "userId": 7,
    "email": "customer@popq.test",
    "name": "POPQ 고객",
    "role": "CUSTOMER",
    "status": "ACTIVE"
  },
  "interestCount": 2,
  "reviewCount": 1,
  "orderCount": 4
}
```

`reviewCount`에는 `ACTIVE` 리뷰만 포함한다. 테이블은 Flyway `V5__create_customer_engagement_tables.sql`에서 생성한다.
