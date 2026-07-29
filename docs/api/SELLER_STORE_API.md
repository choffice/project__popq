# 판매자 사업장 API

기준일: 2026-07-30

## 공통 권한

- 인증 역할은 `SELLER` 또는 `ADMIN`이어야 한다.
- 요청 사용자는 대상 사업장의 활성 `StoreMember`여야 한다.
- 상세 조회는 `OWNER`, `MANAGER`, `STAFF`가 가능하다.
- 상세 수정과 영업 상태 변경은 `OWNER`, `MANAGER`만 가능하다.
- 다른 판매자의 사업장에는 `STORE_ACCESS_DENIED`로 응답한다.

## 사업장 목록

`GET /api/v1/seller/stores`

로그인한 판매자가 소속된 활성 사업장 목록과 각 사업장의 본인 역할을 반환한다.

## 사업장 상세

`GET /api/v1/seller/stores/{storeId}`

응답 필드:

- `storeId`, `storeType`, `name`, `description`
- `address`, `latitude`, `longitude`, `tags`
- `status`, `businessStatus`, `myRole`

## 사업장 상세 수정

`PATCH /api/v1/seller/stores/{storeId}`

요청 예시:

```json
{
  "name": "성수 리뉴얼 사업장",
  "description": "커피와 디저트를 판매합니다.",
  "address": "서울 성동구 연무장길 1",
  "latitude": 37.5445,
  "longitude": 127.0561,
  "tags": ["coffee", "dessert"]
}
```

검증 규칙:

- 이름은 필수이며 최대 150자다.
- 설명은 최대 1,000자, 주소는 최대 255자다.
- 위도와 경도는 함께 입력하거나 함께 비워야 한다.
- 위도는 -90~90, 경도는 -180~180 범위다.
- 태그는 최대 10개, 태그 하나는 최대 30자다.
- 태그는 공백을 제거하고 소문자로 정규화한 뒤 중복을 제거한다.

성공 시 수정된 사업장 상세를 반환한다.

## 영업 상태 변경

`PATCH /api/v1/seller/stores/{storeId}/business-status`

`PREPARING`, `OPEN`, `CLOSED` 중 하나로 변경한다.

