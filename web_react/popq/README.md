# POPQ QR Order Web

모바일 브라우저에서 QR을 스캔한 고객이 메뉴 선택, 옵션 구성, 장바구니, 결제, 실시간 주문 추적을 진행하는 React 웹이다.

## 바로 보기

```powershell
npm.cmd install
npm.cmd run dev
```

브라우저에서 `http://127.0.0.1:5173/`에 접속하면 백엔드 없이 동작하는 데모 모드가 열린다.

루트의 `.env.example`을 `.env`로 복사하고 `docker compose up --build -d`를 실행하면 MySQL·Spring Boot·QR 웹·판매자 웹을 함께 실행할 수 있다. 상세 내용은 `docs/DEPLOYMENT.md`를 따른다.

## 실제 백엔드 연결

Spring Boot API를 `http://localhost:8082`에서 실행한 후 판매자 API로 스토어, 상품, QR을 준비한다. 발급된 QR 토큰으로 다음 주소에 접속한다.

```text
http://127.0.0.1:5173/q/{QR_TOKEN}
```

Vite 개발 서버는 `/api`와 `/ws`를 Spring Boot로 프록시한다.

실제 연결 흐름:

1. QR 토큰으로 GuestSession HttpOnly 쿠키 발급
2. 서버 메뉴와 상품 옵션 조회
3. 서버 재계산 기반 주문 생성
4. `TEST` 환경은 TestPaymentProvider로 즉시 승인하고, `TOSS_PAYMENTS` 환경은 Toss 결제 인증 후 서버 승인
5. STOMP 게스트 주문 채널 구독
6. 이벤트 버전 누락 또는 재접속 시 REST 동기화
7. 결제 전 장바구니와 진행 중 주문을 브라우저 새로고침 후 복구
8. 주문/결제 재시도 시 같은 멱등성 키를 재사용해 중복 생성 방지
9. 접수 전 주문은 고객이 직접 취소하고, 종료 후 새 주문 시작

브라우저 저장소는 화면 복구를 위한 임시 상태만 보관한다. 실제 주문 상태와 금액의 기준은 항상 Spring Boot API와 데이터베이스이며, 복구 직후 서버 상태로 다시 동기화한다.

## Toss Payments 테스트 연동

루트 `.env`에 서로 짝이 맞는 API 개별 연동 테스트 키를 설정한다.

```dotenv
POPQ_PAYMENT_PROVIDER=TOSS_PAYMENTS
POPQ_TOSS_CLIENT_KEY=replace-with-test-client-key
POPQ_TOSS_SECRET_KEY=replace-with-matching-test-secret-key
```

클라이언트 키는 QR 웹 빌드 시 공개 설정으로 포함된다. 시크릿 키는 브라우저 코드에 포함하지 않고 Spring Boot 환경변수로만 전달한다. 결제 성공·실패 URL은 현재 `/q/{QR_TOKEN}` 주소로 돌아오며, 유효한 HttpOnly 게스트 세션을 재사용해 주문 소유권을 유지한다.

## 검증

```powershell
npm.cmd run test
npm.cmd run test:e2e
npm.cmd run lint
npm.cmd run build
```

Playwright 브라우저가 아직 없다면 최초 한 번 `npx.cmd playwright install chromium`을 실행한다.

## 앱 구분

- 이 폴더 `web_react/popq`: QR 고객 주문 웹
- 상위 `web_react` CRA 앱: 기존 초기 템플릿으로 현재 변경하지 않음
- `web_react/seller-web`: 판매자·기본 관리자 운영 웹
