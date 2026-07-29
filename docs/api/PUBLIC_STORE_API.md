# 공개 스토어 탐색 API

소비자 앱이 인증 없이 영업 중인 스토어를 탐색하는 읽기 전용 계약이다. `status=ACTIVE`, `businessStatus=OPEN`인 스토어만 노출한다.

## 검색

```http
GET /api/v1/public/stores
```

선택 쿼리:

| 이름 | 설명 |
|---|---|
| `query` | 이름·설명·주소 부분 검색 |
| `tag` | 스토어 태그 정확 일치, 대소문자 무시 |
| `latitude` | 현재 위도, 경도와 함께 전달 |
| `longitude` | 현재 경도, 위도와 함께 전달 |
| `radiusKm` | 위치가 있을 때만 사용, `0 < radiusKm <= 100` |

위치가 전달되면 `distanceMeters`가 가까운 순으로 정렬된다. 반경 검색에서는 좌표가 없는 스토어를 제외한다.

```json
{
  "success": true,
  "data": [
    {
      "storeId": 1,
      "storeType": "LOCAL_STORE",
      "name": "성수 커피 연구소",
      "description": "매일 새로운 원두를 소개합니다.",
      "businessStatus": "OPEN",
      "address": "서울 성동구 연무장길",
      "latitude": 37.5445000,
      "longitude": 127.0560000,
      "tags": ["coffee", "local"],
      "distanceMeters": 280
    }
  ],
  "error": null,
  "timestamp": "2026-07-29T00:00:00Z"
}
```

## 상세

```http
GET /api/v1/public/stores/{storeId}
```

영업 중이 아니거나 비활성인 스토어는 존재 여부를 공개하지 않고 `STORE_NOT_FOUND`로 응답한다. 상세 응답의 형태는 검색 항목과 같으며 위치 기준이 없으므로 `distanceMeters`는 `null`이다.

## 판매자 생성 확장 필드

`POST /api/v1/seller/stores`에는 기존 필드와 함께 다음 선택 필드를 전달할 수 있다.

```json
{
  "address": "서울 성동구 연무장길",
  "latitude": 37.5445,
  "longitude": 127.0560,
  "tags": ["coffee", "local"]
}
```

위도와 경도는 항상 함께 전달해야 하며 태그는 최대 10개, 각 30자까지 허용한다.

## 소비자 상품·옵션

- `GET /api/v1/public/stores/{storeId}/products`
- `GET /api/v1/public/stores/{storeId}/products/{productId}`

인증 없이 조회할 수 있지만 `ACTIVE + OPEN` 스토어의 `ACTIVE` 상품 중 `customerAppEnabled=true`이고 판매 기간 안에 있는 상품만 노출한다. 목록은 품절 상품을 포함해 품절 상태를 표시할 수 있으며, 회원 주문 생성 시 서버가 판매 가능 상태를 다시 검증한다.

상세 응답의 `optionGroups`는 각 그룹의 `minSelect`, `maxSelect`, `required`와 옵션별 `additionalPrice`를 제공한다. 클라이언트는 선택 UI를 구성할 때 사용하고 최종 검증과 가격 계산은 서버가 수행한다.
