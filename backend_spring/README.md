# POPQ Spring Boot API

POPQ의 React 및 Flutter 클라이언트가 함께 사용하는 공통 REST API 서버다.

## 요구 환경

- Java 17
- Docker Desktop 또는 MySQL 8.4+
- Windows에서는 Gradle Wrapper `gradlew.bat` 사용

## 로컬 데이터베이스

프로젝트 루트에서 환경 파일을 준비한다.

```powershell
Copy-Item .env.example .env
```

`.env`의 비밀번호와 JWT secret을 로컬 값으로 변경한 후 MySQL을 실행한다.

```powershell
docker compose --env-file .env up -d mysql
docker compose --env-file .env ps
```

기본 연결 정보는 다음과 같다.

- Database: `popq`
- Host: `localhost`
- Port: `3306`
- User: `popq`

테이블은 애플리케이션 시작 시 Flyway가 생성한다. Hibernate는 스키마를 임의로 변경하지 않고 `validate`만 수행한다.

## 개발 프로파일 실행

Spring Boot 프로세스에는 비밀값을 환경변수로 전달한다.

```powershell
$env:POPQ_DB_PASSWORD = "로컬 DB 비밀번호"
$env:POPQ_JWT_SECRET = "32바이트 이상의 로컬 개발용 무작위 문자열"
$env:POPQ_QR_TOKEN_ENCRYPTION_KEY = "32바이트 이상의 별도 QR 암호화 키"
.\gradlew.bat bootRun --args="--spring.profiles.active=dev"
```

개발 프로파일에서만 `/api/v1/dev/auth/login`을 사용할 수 있다. 운영 기본 설정에서는 개발 로그인이 비활성화된다.

개발용 판매자 로그인 예시:

```powershell
$body = @{
  email = "seller@popq.local"
  name = "로컬 판매자"
  role = "SELLER"
} | ConvertTo-Json

$login = Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:8082/api/v1/dev/auth/login" `
  -ContentType "application/json" `
  -Body $body

$token = $login.data.accessToken
Invoke-RestMethod `
  -Uri "http://localhost:8082/api/v1/auth/me" `
  -Headers @{ Authorization = "Bearer $token" }
```

## 테스트

테스트는 별도의 H2 인메모리 데이터베이스를 MySQL 호환 모드로 실행한다. 로컬 MySQL 데이터는 변경하지 않는다.

```powershell
.\gradlew.bat clean test --no-daemon
```

현재 테스트 범위:

- Spring Context와 Flyway/JPA 스키마 검증
- 개발용 JWT 로그인
- 비인증 요청 401 공통 오류 응답
- CUSTOMER의 판매자 API 접근 거부
- SELLER의 스토어 생성 및 OWNER 권한
- STAFF의 관리 권한 거부
- 다른 스토어 사용자 접근 거부
- 카테고리·상품·옵션·품절 상태
- 다른 스토어 상품 수정 거부
- QR 원문 평문 미저장·암호문 복원과 GuestSession 원문 미저장
- 비활성·폐기·만료 QR 접근 거부
- QR 재발급 후 기존 토큰 차단
- 비회원 세션 기반 상품 목록·상세 조회
- 주문 금액 서버 재계산과 상품·옵션 스냅샷
- 주문·결제 멱등성 및 결제 실패 이력 보존
- 비회원 주문 소유권과 판매자 스토어 범위 검증
- 주문 상태 전이와 낙관적 잠금
- 고객 취소·판매자 거절 시 결제 취소 및 환불 이력
- 게스트 주문부터 판매자 접수까지 HTTP API 통합 흐름
- 주문 상태 이벤트의 `AFTER_COMMIT` STOMP 발행
- 판매자 스토어 구독·게스트 주문 구독 인가
- 주문 버전 기반 재접속 REST 동기화

## 현재 주요 API

### 판매자

- `GET/POST /api/v1/seller/stores`
- `PATCH /api/v1/seller/stores/{storeId}/business-status`
- `GET/POST /api/v1/seller/stores/{storeId}/tables`
- `GET/POST /api/v1/seller/stores/{storeId}/categories`
- `GET/POST /api/v1/seller/stores/{storeId}/products`
- `PUT /api/v1/seller/stores/{storeId}/products/{productId}/options`
- `PATCH /api/v1/seller/stores/{storeId}/products/{productId}/availability`
- `GET/POST /api/v1/seller/stores/{storeId}/qr-codes`
- `GET /api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}`
- `POST /api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/activate`
- `POST /api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/deactivate`
- `POST /api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/revoke`
- `POST /api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/reissue`
- `POST /api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/archive`
- `POST /api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/restore`
- `GET /api/v1/seller/stores/{storeId}/orders?status={status}`
- `GET /api/v1/seller/stores/{storeId}/orders/{orderPublicId}`
- `GET /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/sync?knownVersion={version}`
- `POST /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/accept`
- `POST /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/reject`
- `POST /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/prepare`
- `POST /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/ready`
- `POST /api/v1/seller/stores/{storeId}/orders/{orderPublicId}/complete`

### 비회원 QR

- `POST /api/v1/qr/{opaqueToken}/sessions`
- `GET /api/v1/qr/context`
- `GET /api/v1/qr/products`
- `GET /api/v1/qr/products/{productId}`
- `POST /api/v1/qr/orders`
- `GET /api/v1/qr/orders/{orderPublicId}`
- `GET /api/v1/qr/orders/{orderPublicId}/sync?knownVersion={version}`
- `POST /api/v1/qr/orders/{orderPublicId}/payments`
- `POST /api/v1/qr/orders/{orderPublicId}/cancel`

QR 원문 토큰은 고객 조회용 SHA-256 해시와 판매자 보관함 복원용 AES-GCM 암호문으로 저장한다. 암호화 키는 `POPQ_QR_TOKEN_ENCRYPTION_KEY`로 주입하며, 운영에서는 JWT 키와 다른 값을 사용한다. 비회원 세션 원문 토큰은 HttpOnly 쿠키로만 전달하고 데이터베이스에는 SHA-256 해시만 저장한다.
폐기된 QR의 목록 제거는 주문·게스트 세션 이력을 보존하도록 `archived_at` 기반 소프트 삭제로 처리한다.
주문 및 결제 요청의 `idempotencyKey`는 8~100자의 영문·숫자·`_`·`-` 조합이며, 클라이언트에서 요청 단위 UUID를 생성해 재시도 동안 동일하게 사용한다.

주문·결제 상세 계약은 [`../docs/api/ORDER_PAYMENT_API.md`](../docs/api/ORDER_PAYMENT_API.md)를 참고한다.

## 실시간 주문 상태

- STOMP 연결 endpoint: `/ws`
- 판매자 구독: `/topic/stores/{storeId}/orders`
- 게스트 구독: `/user/queue/orders/{orderPublicId}`
- 판매자는 STOMP `CONNECT`의 `Authorization: Bearer {JWT}` 헤더를 사용한다.
- 게스트는 WebSocket handshake에 자동 포함되는 `POPQ_GUEST_SESSION` HttpOnly 쿠키를 사용한다.
- 서버는 `CONNECT` 인증 후 모든 `SUBSCRIBE`에서 스토어 멤버십 또는 주문 소유권을 다시 확인한다.
- 현재 simple broker는 단일 서버 개발·MVP용이다. 서버 수평 확장 시 외부 broker relay로 교체한다.

연결·이벤트·복구 계약은 [`../docs/api/REALTIME_API.md`](../docs/api/REALTIME_API.md)를 참고한다.

## 설정 원칙

- 실제 비밀값은 저장소에 커밋하지 않는다.
- `.env.example`에는 예시 키만 둔다.
- JWT secret은 최소 32바이트 이상을 사용한다.
- QR 토큰 암호화 키는 최소 32바이트 이상이며 JWT secret과 다른 값을 사용한다.
- 운영에서는 HTTPS, 허용 Origin CORS, 쿠키 기반 요청의 CSRF 정책을 적용한다.
