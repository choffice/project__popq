# POPQ 통합 실행·배포

## 서비스 구성

| 서비스 | 기본 주소 | 역할 |
|---|---|---|
| QR 웹 | `http://localhost:5173` | 고객 메뉴·주문·결제·추적 |
| 판매자 웹 | `http://localhost:5174` | 주문·상품·QR·환불·관리자 운영 |
| Spring Boot | `http://localhost:8082` | REST·STOMP·헬스체크 |
| MySQL | `127.0.0.1:3307` | 영속 데이터(호스트에서는 로컬만 허용) |

두 React 컨테이너는 Nginx로 정적 파일을 제공하고 같은 Origin의 `/api`와 `/ws`를 `backend:8082`로 프록시한다. 브라우저에서 백엔드를 직접 호출할 때는 환경변수의 Origin 허용 목록을 사용한다.

## 최초 실행

```powershell
Copy-Item .env.example .env
```

`.env`의 다음 값은 반드시 교체한다.

- `POPQ_DB_PASSWORD`
- `POPQ_DB_ROOT_PASSWORD`
- `POPQ_JWT_SECRET`: 최소 32바이트 이상의 무작위 값
- `POPQ_QR_TOKEN_ENCRYPTION_KEY`: JWT 키와 다른 최소 32바이트 이상의 무작위 값

실제 Toss 테스트 결제를 사용할 때는 다음 값도 설정한다. `POPQ_TOSS_CLIENT_KEY`와 `POPQ_TOSS_SECRET_KEY`는 같은 API 개별 연동 키 세트여야 한다.

- `POPQ_PAYMENT_PROVIDER=TOSS_PAYMENTS`
- `POPQ_TOSS_CLIENT_KEY`: QR 웹 빌드에 포함되는 공개 클라이언트 키
- `POPQ_TOSS_SECRET_KEY`: Spring Boot에만 전달하는 비밀 키

구성을 확인하고 전체 서비스를 실행한다.

```powershell
docker compose config
docker compose up --build -d
docker compose ps
```

종료:

```powershell
docker compose down
```

MySQL과 업로드 파일은 Docker volume에 보존된다. 데이터까지 제거하는 `docker compose down -v`는 복구가 필요한 데이터가 없는 경우에만 사용한다.

## 헬스체크

- 백엔드: `GET http://localhost:8082/actuator/health`
- QR 웹 컨테이너: `GET /healthz`
- 판매자 웹 컨테이너: `GET /healthz`

웹 컨테이너는 백엔드가 `UP` 상태가 된 후 시작하고, 백엔드는 MySQL healthcheck 통과 후 시작한다.

## 보안 설정

- REST API는 세션을 만들지 않는 Bearer JWT 방식이다.
- QR 게스트 쿠키는 `HttpOnly`, `SameSite=Lax`이며 운영 HTTPS에서는 `POPQ_COOKIE_SECURE=true`를 사용한다.
- CSRF는 stateless Bearer API와 SameSite 게스트 쿠키 구조에 맞춰 비활성화되어 있다.
- 개발 로그인은 `dev` 프로파일에서도 기본 비활성화되며, 로컬 스모크 테스트 중에만 `POPQ_DEV_LOGIN_ENABLED=true`로 명시적으로 켠다.
- 브라우저 직접 호출은 `POPQ_WEB_ALLOWED_ORIGINS`의 Origin만 허용한다.
- STOMP handshake는 `POPQ_REALTIME_ALLOWED_ORIGINS`의 Origin만 허용한다.
- Nginx는 `/api`, `/ws`만 백엔드로 전달하며 나머지는 SPA 정적 파일로 처리한다.

## 운영 환경 체크리스트

```dotenv
POPQ_SPRING_PROFILES_ACTIVE=prod
POPQ_DEV_LOGIN_ENABLED=false
POPQ_COOKIE_SECURE=true
POPQ_QR_PUBLIC_BASE_URL=https://order.example.com
POPQ_QR_TOKEN_ENCRYPTION_KEY=replace-with-a-separate-random-secret-at-least-32-bytes
POPQ_PAYMENT_PROVIDER=TOSS_PAYMENTS
POPQ_TOSS_CLIENT_KEY=replace-with-live-client-key
POPQ_TOSS_SECRET_KEY=replace-with-matching-live-secret-key
POPQ_WEB_ALLOWED_ORIGINS=https://order.example.com,https://seller.example.com
POPQ_REALTIME_ALLOWED_ORIGINS=https://order.example.com,https://seller.example.com
```

운영에서는 MySQL 포트와 Spring Boot 포트를 외부에 직접 공개하지 않고 리버스 프록시 또는 내부 네트워크를 통해 접근시키는 구성을 권장한다.
QR 결제 도메인은 HTTPS로 제공하고 `POPQ_COOKIE_SECURE=true`를 유지한다.

## 장애 확인

```powershell
docker compose ps
docker compose logs --tail 200 backend
docker compose logs --tail 100 qr-web seller-web
```

Flyway 실패는 데이터베이스 연결 정보와 기존 스키마 버전을 먼저 확인한다. 웹은 정상인데 API가 실패하면 백엔드 healthcheck와 Nginx `/api` 프록시를 확인한다. 실시간 주문만 끊기면 `/ws` Upgrade 헤더와 STOMP Origin 허용 목록을 확인한다.
