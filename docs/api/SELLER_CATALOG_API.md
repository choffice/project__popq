# 판매자 카탈로그 API

판매자 웹의 카테고리, 상품, 옵션, 판매 가능 상태 관리 계약이다. 모든 경로는 Bearer Access Token이 필요하며 `{storeId}`에 소속된 스토어 멤버만 접근할 수 있다.

## 권한

- 조회: OWNER, MANAGER, STAFF
- 카테고리·상품 생성·수정, 옵션 교체: OWNER, MANAGER
- 품절·판매 기간·채널 상태 변경: OWNER, MANAGER, STAFF

다른 스토어의 카테고리나 상품 ID를 전달해도 현재 스토어 범위를 벗어나 조회하거나 변경할 수 없다.

## 엔드포인트

| Method | Path | 설명 |
|---|---|---|
| GET | `/api/v1/seller/stores/{storeId}/categories` | 카테고리 목록 |
| POST | `/api/v1/seller/stores/{storeId}/categories` | 카테고리 생성 |
| PATCH | `/api/v1/seller/stores/{storeId}/categories/{categoryId}` | 카테고리 이름·정렬 순서 수정 |
| GET | `/api/v1/seller/stores/{storeId}/products` | 활성 상품 요약 목록 |
| POST | `/api/v1/seller/stores/{storeId}/products` | 기본 상품 생성 |
| GET | `/api/v1/seller/stores/{storeId}/products/{productId}` | 옵션을 포함한 상품 상세 |
| PATCH | `/api/v1/seller/stores/{storeId}/products/{productId}` | 카테고리·이름·설명·이미지·가격 수정 |
| PUT | `/api/v1/seller/stores/{storeId}/products/{productId}/options` | 옵션 구조 전체 교체 |
| PATCH | `/api/v1/seller/stores/{storeId}/products/{productId}/availability` | 품절·판매 기간·채널 상태 변경 |

## 상품 생성

```json
{
  "categoryId": 9,
  "name": "수박 소다",
  "description": "여름 한정 탄산 음료",
  "imageUrl": null,
  "basePrice": 7200
}
```

`basePrice`는 0 이상의 정수 금액이다. `categoryId`는 같은 스토어의 카테고리여야 한다.
상품 수정도 같은 필드 구조를 사용하며 기존 옵션과 판매 가능 상태는 보존한다.

## 옵션 전체 교체

```json
{
  "groups": [
    {
      "name": "온도",
      "minSelect": 1,
      "maxSelect": 1,
      "required": true,
      "displayOrder": 0,
      "options": [
        {
          "name": "HOT",
          "additionalPrice": 0,
          "displayOrder": 0
        },
        {
          "name": "ICE",
          "additionalPrice": 500,
          "displayOrder": 1
        }
      ]
    }
  ]
}
```

`PUT` 요청은 부분 수정이 아니라 전체 교체다. 저장 후 기존 옵션 그룹과 옵션은 요청한 구조로 대체된다. 각 그룹은 옵션을 하나 이상 가져야 하며 `minSelect <= maxSelect <= options.length`를 만족해야 한다.

## 판매 가능 상태 변경

클라이언트는 일부 스위치만 바꾸더라도 현재 계약의 모든 필드를 보존해 전송한다.

```json
{
  "soldOut": false,
  "salesStartAt": null,
  "salesEndAt": null,
  "qrWebEnabled": true,
  "customerAppEnabled": true
}
```

`availableForQr`는 서버가 품절, 판매 기간, 상품 상태, QR 채널 상태를 종합해 계산한다.
