# 판매자 매출 분석 API

## 매출 요약

```text
GET /api/v1/seller/stores/{storeId}/analytics/sales?from=2026-07-23&to=2026-07-29
```

- 날짜는 `Asia/Seoul` 영업일 기준이다.
- 조회 시작일과 종료일을 포함하며 최대 31일까지 조회할 수 있다.
- OWNER, MANAGER, STAFF가 소속 스토어만 조회할 수 있다.
- 주문 생성일이 아니라 `COMPLETED` 상태 전환 시각으로 일별 매출을 집계한다.
- 취소·거절·만료·진행 중 주문은 순매출에서 제외한다.

응답 데이터:

```json
{
  "from": "2026-07-23",
  "to": "2026-07-29",
  "netSales": 1373500,
  "completedOrderCount": 121,
  "averageOrderAmount": 11351,
  "dineInSales": 933980,
  "takeoutSales": 439520,
  "dailySales": [
    {
      "date": "2026-07-23",
      "sales": 176500,
      "orderCount": 16
    }
  ],
  "topProducts": [
    {
      "productName": "블랙 세서미 크림 라떼",
      "quantity": 56,
      "sales": 380800
    }
  ]
}
```

상품별 매출은 주문 당시 상품명과 금액 스냅샷을 사용하므로 이후 상품명이나 가격이 변경되어도 과거 집계가 바뀌지 않는다.
