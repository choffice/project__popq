# POPQ Seller Web

## 개발용 판매자 토큰 한 번에 발급

프로젝트 루트에서 다음 명령을 실행한다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev-seller-token.ps1
```

스크립트는 로컬 MySQL과 백엔드를 시작하고, 개발용 판매자와 테스트
스토어를 준비한 뒤 10년짜리 Access Token을 클립보드에 복사한다.
출력된 Store ID와 복사된 토큰을 판매자 웹의 `백엔드 연결` 창에 입력한다.

판매자가 신규 주문을 접수하고 준비·전달 완료까지 실시간으로 운영하는 React 웹이다.

## 바로 보기

```powershell
npm.cmd install
npm.cmd run dev
```

기본 주소는 `http://127.0.0.1:5174/`이며, 백엔드 없이 실행 가능한 데모 주문이 표시된다.

루트의 `.env.example`을 `.env`로 복사하고 `docker compose up --build -d`를 실행하면 MySQL·Spring Boot·QR 웹·판매자 웹을 함께 실행할 수 있다. 상세 내용은 `docs/DEPLOYMENT.md`를 따른다.

## 구현 범위

- 오늘의 진행 주문·신규 접수·전달 대기·완료 매출 요약
- 신규 주문, 준비 중, 전달 대기 칸반 보드
- 주문 상세, 상품·옵션·결제 금액·상태 이력
- 주문별 결제 상태·환불 이력 조회와 완료 주문 전액 환불
- 접수, 거절, 준비 시작, 준비 완료, 전달 완료 상태 변경
- 진행 중·신규·전달 대기·완료 필터
- 상품 검색·카테고리 필터와 즉시 품절 처리
- 카테고리 추가와 기본 상품 생성
- 옵션 그룹·필수 여부·최대 선택 수·옵션별 추가 금액 편집
- QR 웹·고객 앱 채널별 상품 판매 상태 전환
- 테이블 QR 목록·발급·만료·중지·재활성화·폐기
- 발급 직후 실제 스캔 가능한 QR PNG 생성·다운로드
- 완료 시각 기준 7일·30일 매출, 주문 수, 평균 주문 금액
- 일별 매출 차트, 매장·포장 비중, 인기 상품
- 스토어 영업 상태 변경과 테이블 추가
- 관리자 사용자·판매자 인증·스토어 목록과 상태 관리
- 데스크톱·태블릿·모바일 반응형 레이아웃
- 판매자 REST API 및 STOMP 실시간 주문 연결

## 실제 백엔드 연결

우측 상단 연결 설정에서 스토어 ID와 판매자 Access Token을 입력한다. 토큰은 영구 저장하지 않고 현재 브라우저 탭의 `sessionStorage`에만 보관한다.

Vite 개발 서버는 `/api`와 `/ws`를 `http://localhost:8082`로 프록시한다.

연결 API:

- `GET /api/v1/seller/stores/{storeId}/orders`
- `POST .../{orderPublicId}/accept|reject|prepare|ready|complete`
- `GET .../{orderPublicId}/payment`
- `POST .../{orderPublicId}/refunds`
- `GET /api/v1/seller/stores/{storeId}/products`
- `GET|POST /api/v1/seller/stores/{storeId}/categories`
- `POST /api/v1/seller/stores/{storeId}/products`
- `GET /api/v1/seller/stores/{storeId}/products/{productId}`
- `PUT .../products/{productId}/options`
- `PATCH .../products/{productId}/availability`
- `GET /api/v1/seller/stores/{storeId}/tables`
- `GET|POST /api/v1/seller/stores/{storeId}/qr-codes`
- `POST .../qr-codes/{qrCodeId}/activate|deactivate|revoke`
- `GET .../analytics/sales?from={date}&to={date}`
- `PATCH /api/v1/seller/stores/{storeId}/business-status`
- `POST /api/v1/seller/stores/{storeId}/tables`
- `GET /api/v1/admin/overview|users|sellers|stores`
- `PATCH /api/v1/admin/users/{userId}/status`
- `PATCH /api/v1/admin/sellers/{sellerProfileId}/verification`
- `PATCH /api/v1/admin/stores/{storeId}/status`
- STOMP `/topic/stores/{storeId}/orders`

실제 주문과 금액의 최종 기준은 항상 Spring Boot API와 데이터베이스다.

## 검증

```powershell
npm.cmd run test
npm.cmd run lint
npm.cmd run build
```
