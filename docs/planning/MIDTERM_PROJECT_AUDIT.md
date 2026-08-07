# POPQ 프로젝트 중간점검

- 점검일: 2026-08-07
- 점검 브랜치: `suyeon`
- 범위: `backend_spring`, `mobile_flutter`, `web_react`, `deploy`, `docker-compose.yml`, `scripts`, 루트 설정 및 지정 문서 전체
- 원칙: 소스·설정·DB는 변경하지 않았고, 확인된 문제도 삭제·리팩터링하지 않았다.
- 표기: **확인됨**은 코드·설정·실행 결과로 직접 확인한 내용이고, **추정**은 운영 환경이나 실제 외부 계정이 없어 정적 근거로 판단한 내용이다.

## 1. 전체 상태 요약

전체 완성도는 **기능 구현량은 높지만 공개 운영 준비도는 낮은 중간 단계**다. QR 주문, 회원 주문, 판매자 주문·상품·QR·공지·메시지·매출의 주요 코드가 존재하고 React 두 앱은 현재 검증을 통과했다. 그러나 Backend 테스트 소스가 현재 컴파일되지 않고, 인증 복구·비밀번호 재설정·비밀값 관리·DB 스키마 운영 정책에 P0 문제가 있다. 실제 PG·FCM·OAuth·Docker 통합 E2E도 완료 증거가 없다.

| 영역 | 평가 | 근거 |
|---|---|---|
| Backend | 위험 | 핵심 도메인과 권한 검증은 갖췄으나 `PaymentServiceTests` 컴파일 실패, 비밀번호 재설정 인증 부재, 무제한 목록·N+1 후보, Flyway와 `ddl-auto: update` 병용 |
| Customer Flutter | 보완 필요 | 탐색·상품·주문·관심·리뷰·알림·문의 API 연결 확인. 홈 추천/랭킹과 프로필 일부는 임시값, Refresh Token 미구현, 이번 환경에서 analyze/test 정지 |
| Seller Flutter | 보완 필요 | 인증·스토어·주문·상품·공지·고객문의·리뷰·매출 연결 확인. QR/테이블 운영 UI와 정산 미구현, Refresh Token 미구현, 매우 큰 Widget 다수 |
| QR Web | 양호 | lint, 17개 테스트, production build, 데모 E2E 2개 통과. 실제 Backend/PG E2E가 아니며 무토큰 진입 시 데모 모드 제공 |
| Seller Web | 보완 필요 | 로그인·스토어 선택·주문·상품·QR·매출·공지·문의·관리자 연결, lint·37개 테스트·build 통과. 토큰 갱신/공통 401·403 처리 없음 |
| Deployment | 위험 | Docker 구성과 헬스체크는 있으나 기본 `dev`/TEST 구성, Firebase 서버 설정 전달 누락, Backend/DB 포트 공개, CSP/HSTS 없음 |
| Test | 위험 | Backend 테스트 컴파일 실패. Flutter 도구 정지. 실제 통합 E2E·CI 없음. React 로컬 검증만 현재 PASS |
| Security | 위험 | 추적 중인 모바일 외부연동 값, 무인증 비밀번호 재설정, 판매자 검증 우회 가능성, Refresh Token 부재 |

## 2. 핵심 결론 TOP 10

1. **[Critical, 확인됨] 비밀번호 재설정이 이메일+전화번호 일치만으로 새 비밀번호를 즉시 설정한다.** OTP, 일회용 토큰, 만료, 시도 제한이 없다. `backend_spring/src/main/java/com/example/project_popq/auth/service/AuthService.java`, `backend_spring/src/main/java/com/example/project_popq/auth/dto/PasswordResetConfirmRequest.java`.
2. **[Critical, 확인됨] 실제로 구성된 모바일 외부연동 값이 Git 추적 파일에 있다.** Naver Client Secret 성격의 값과 Toss 클라이언트 키가 `mobile_flutter/config/*.dev.env`에 있고 Firebase 구성 파일도 추적된다. 값 자체는 이 보고서에 기록하지 않는다.
3. **[P0, 확인됨] Backend 테스트가 컴파일되지 않는다.** `PaymentService`가 `PaymentProviderRegistry`를 받도록 변경됐지만 `PaymentServiceTests`는 `PaymentProvider`를 직접 전달한다. `backend_spring/src/test/java/com/example/project_popq/payment/service/PaymentServiceTests.java:68`.
4. **[High, 확인됨] Access Token만 발급하며 Refresh Token API·저장소·회전·폐기 계약이 없다.** Flutter는 빈 문자열을 저장하고, Web은 토큰을 `sessionStorage`에 저장한다. 공통 401 갱신/로그인 복귀 계층도 없다.
5. **[High, 확인됨] 공개 인증 사용자가 스스로 SELLER 역할을 추가할 수 있고, VERIFIED 판매자 여부 없이 스토어 생성이 가능하다.** `POST /api/v1/auth/connect-seller`와 `StoreApplicationService.create`가 판매자 프로필 인증 상태를 확인하지 않는다.
6. **[High, 확인됨] Flyway를 사용하면서 Hibernate `ddl-auto: update`도 활성화돼 있다.** 운영 스키마 변경 책임이 이중화되어 예측하지 못한 스키마 변형 위험이 있다. `backend_spring/src/main/resources/application.yml`.
7. **[High, 확인됨] 주문·관리자·공지·관심·리뷰 등 주요 목록 다수가 pagination 없이 전체 조회한다.** 주문 DTO 변환은 여러 LAZY 연관을 순회해 N+1 가능성도 높다.
8. **[High, 추정] 실제 Toss 호출이 DB 트랜잭션·비관적 잠금 안에서 실행되고 HTTP timeout이 명시되지 않았다.** PG 지연 시 주문/결제 행 잠금이 장시간 유지될 수 있다.
9. **[P1, 확인됨] 문서가 코드보다 크게 뒤처졌다.** 공지·고객문의·판매자 리뷰·실제 소셜 로그인·FCM 클라이언트·판매자 웹 로그인은 구현됐지만 일부 계획서는 여전히 미구현/수동 토큰 상태로 기록한다.
10. **[P1, 확인됨] 실제 전체 흐름 E2E와 CI가 없다.** QR Playwright는 데모 모드만 검증하며, Seller Web·Flutter·Spring·MySQL을 함께 실행하는 교차 채널 테스트와 `.github/workflows`가 없다.

## 3. 기능 구현 현황표

| 기능 | Client | Backend | DB | 연동 | 상태 | 남은 작업 |
|---|---|---|---|---|---|---|
| 이메일 회원가입·로그인 | Customer/Seller Flutter, Seller Web | Auth API | users, user_roles | 연결 | 🟡 부분 구현 | Refresh Token, 시도 제한, 운영 세션 정책 |
| Google/Kakao/Naver 로그인 | Customer/Seller Flutter | 토큰 검증·계정 연결 | social_accounts | 연결 코드 확인 | 🟡 부분 구현 | 키 회수/재주입, 실제 계정·심사·E2E |
| 비밀번호 찾기/재설정 | Flutter 양 앱 | Auth API | users | 연결 | 🟡 부분 구현 | 본인확인 OTP/일회용 토큰 없으므로 공개 금지 |
| 고객 스토어 탐색 | Customer Flutter | Public Store/Location API | stores, tags | 연결 | ✅ 구현 완료 | 대량 목록 pagination, 지도 공급자 운영 QA |
| 고객 홈 추천·랭킹·이벤트 | Customer Flutter | 전용 API 없음 | 없음 | 미연결 | 🟠 UI/임시 데이터 | 추천·이벤트·랭킹 계약 또는 섹션 범위 재결정 |
| 관심 스토어 | Customer Flutter | Customer Engagement API | store_interests | 연결 | ✅ 구현 완료 | pagination, 실제 회귀 재검증 |
| 상품·옵션 조회 | QR Web, Customer Flutter | QR/Public Catalog API | products/options | 연결 | ✅ 구현 완료 | 실제 Backend E2E |
| 장바구니 | QR Web, Customer Flutter | 클라이언트 상태+서버 주문 검증 | 주문 생성 시 저장 | 연결 | ✅ 구현 완료 | 복수 기기/복구 정책 QA |
| QR 비회원 주문 | QR Web | QR/Guest Order API | qr_codes, guest_sessions, orders | 연결 | 🟡 부분 구현 | 현재 Backend build 복구, 실제 DB E2E |
| 회원 주문 | Customer Flutter | Customer Order API | orders/items/history | 연결 | 🟡 부분 구현 | Backend build, 실제 통합 E2E, pagination |
| Toss 결제 | QR Web, Customer Flutter(Android) | Toss Provider/Test Provider | payments/transactions | 코드 연결 | 🔵 외부 설정 대기 | 키 교체, webhook/대사, timeout, 실제 테스트 |
| 주문 실시간 상태 | QR/Seller Web STOMP, Flutter REST/STOMP/FCM | Realtime + sync API | orders/version | 연결 | 🟡 부분 구현 | 다중 인스턴스 broker, 재연결 통합 E2E |
| 판매자 주문 처리 | Seller Web/Flutter | Seller Order API | orders/history | 연결 | ✅ 구현 완료 | 현재 Backend 테스트 복구, 교차 채널 E2E |
| 판매자 상품/옵션 | Seller Web/Flutter | Catalog API | catalog tables | 연결 | ✅ 구현 완료 | 대량 목록, 이미지 운영 저장소 |
| 판매자 QR/테이블 | Seller Web | QR/Store API | qr_codes/store_tables | 연결 | ✅ Web 완료 | Seller Flutter UI는 ❌ 미구현 |
| 판매자 스토어 운영 | Seller Web/Flutter | Store API | stores/schedules | 연결 | ✅ 구현 완료 | 판매자 인증 승인 게이트, 주소 정책 |
| 공지 관리 | Seller Web/Flutter | Announcement API | announcements | 연결 | ✅ 내부 관리 완료 | 고객/QR 노출·예약·만료 정책 |
| 고객 문의/채팅 | Customer/Seller Flutter, Seller Web | Order Message REST/STOMP | order_messages | 연결 | 🟡 부분 구현 | 보존·신고·차단 정책, 부하/E2E |
| 고객 리뷰 | Customer Flutter, Seller Flutter | Customer/Seller Review API | reviews | 연결 | ✅ 텍스트 완료 | 리뷰 이미지·검수 |
| 푸시 알림 | Flutter 양 앱 | Firebase/Logging Gateway | push_devices/notifications | 부분 연결 | 🔵 외부 설정 대기 | 서버 자격증명·배포 env·실기기 송수신 |
| 매출 분석 | Seller Web/Flutter | Sales Analytics API | 주문·결제 원본 집계 | 연결 | ✅ 기본 완료 | pagination 불필요하나 정산/대사/환불 지표 보강 |
| 관리자 기본 운영 | Seller Web | Admin API | users/sellers/stores | 연결 | ✅ 기본 완료 | pagination, 감사 로그, 주문·결제 운영 확장 |
| 정산 | 없음 | 없음 | 없음 | 없음 | 🔵 정책 결정 대기 | 정산 원장·주기·세무·PG 대사 정책 |

## 4. 미구현 기능

- **확인됨:** Refresh Token 발급·갱신·회전·폐기 API와 클라이언트 자동 복구.
- **확인됨:** 판매자 Flutter의 QR 발급·재발급·비활성·테이블 관리 UI. Seller 앱 소스에는 QR 관리 화면/Repository가 없다.
- **확인됨:** 정산 원장, 정산 예정/완료/공제 내역, 지급 상태.
- **확인됨:** 리뷰 이미지 모델·업로드·검수·삭제. 현재 리뷰는 텍스트만 지원한다.
- **확인됨:** StoreMember 초대·역할 변경·해제 API/UI.
- **확인됨:** 관리자 감사 로그와 주문·결제·보상 운영 화면.
- **확인됨:** CI workflow 및 실제 통합 스택 E2E.
- **확인됨:** 고객 홈 이벤트·랭킹·포인트·레벨을 제공하는 서버 계약.

## 5. 부분 구현 기능

- 인증/세션: 로그인과 만료 시각 저장은 있으나 갱신이 없고 API 요청 중 401을 전역 처리하지 않는다.
- 결제: Test/Toss Provider와 클라이언트 인증 UI는 있으나 실제 키 운영, webhook, 대사, 통신 timeout, 장애 복구 검증이 없다.
- FCM: Flutter 초기화·기기 등록, Spring Firebase Gateway는 있으나 Docker/배포 설정과 실기기 송수신 증거가 없다.
- 판매자 승인: SellerProfile의 PENDING/VERIFIED/REJECTED는 있으나 실제 스토어 생성/운영 권한 게이트로 사용되지 않는다.
- 채팅: REST/STOMP와 읽음·pagination 일부는 있으나 운영 정책, 신고/차단, 보존, 실제 부하 테스트가 없다.
- 공지: 판매자 내부 CRUD는 완료됐으나 고객/QR 공개 노출과 게시 예약·만료가 없다.
- 배포: 로컬 Docker 구성은 있으나 운영 비밀값·TLS·도메인·Firebase·백업·관측성 구성이 완결되지 않았다.

## 6. Mock / 임시 구현

- `web_react/popq/src/data/demo.ts`, `web_react/popq/src/App.tsx`: QR 토큰 없이 진입하면 주문·결제·상태 전이가 전부 데모 데이터로 동작한다. 공개 운영에서 데모 진입 허용 여부를 결정해야 한다.
- `web_react/seller-web/src/data/demo.ts`, `web_react/seller-web/src/App.tsx`: 로그인 화면의 데모 운영 모드. 운영 빌드 노출 정책이 필요하다.
- `mobile_flutter/apps/customer_app/lib/src/features/home/customer_home_content.dart`: 이벤트·추천·랭킹 임시 콘텐츠.
- `mobile_flutter/apps/customer_app/lib/src/features/profile/customer_profile_screen.dart`: 레벨·포인트 등 API 없는 임시값과 “준비 중” 메뉴.
- `mobile_flutter/apps/customer_app/lib/src/features/catalog/catalog_repository.dart`, `store_discovery_repository.dart`: Memory/sample 저장소는 주로 테스트 주입용이나 실제 홈은 API 실패 시 임시 콘텐츠를 표시해 장애를 정상 데이터처럼 보일 수 있다.
- `backend_spring/src/main/java/com/example/project_popq/dev/DevDataInitializer.java`: dev 프로파일 seed 데이터. 운영 프로파일 및 환경변수 방어를 계속 유지해야 한다.
- `PaymentService`의 `simulateFailure`: TEST Provider 전용 계약이지만 public DTO에 포함된다. 운영 Provider에서 무시되더라도 API 계약 분리 후보다.

## 7. 추가 구현 권장 기능

### A. 원래 기획됐으나 미완료

- 필수: Refresh Token과 공통 401 복구.
- 필수: 판매자 인증/승인 게이트.
- 필수: 실제 PG 운영 계약·webhook·대사.
- 필수: CI 및 실제 주문 통합 E2E.
- 권장: Seller Flutter QR/테이블 운영.
- 권장: StoreMember 권한 관리.
- 권장: 정산 상세와 관리자 감사 로그.
- 권장: 리뷰 이미지 저장·리사이징·검수.

### B. 서비스 구조상 추가로 필요한 기능

- 필수: 비밀번호 재설정 OTP/일회용 토큰, 만료, 재사용 방지, 시도 제한.
- 필수: 비밀값 회전 절차와 저장소 secret scanning.
- 필수: 결제 webhook 서명 검증·정기 대사·수동 복구 큐.
- 필수: Flyway 단일 스키마 변경 정책과 운영 `ddl-auto` 차단.
- 권장: API pagination 공통 규격(cursor 또는 page/size)과 최대 size 제한.
- 권장: 요청 상관관계 ID, 구조화 로그, 오류 수집, 메트릭/알림.
- 권장: 이미지 업로드 바이러스/디코딩 검증, 픽셀 제한, 객체 저장소 전환.
- 권장: 계정/비밀번호/결제 API rate limit과 보안 이벤트 감사.
- 있으면 좋음: 추천/랭킹 설명 가능성, 운영 분석 대시보드, 고객지원 도구.

## 8. Frontend ↔ Backend 불일치

정적 경로 대조에서 현재 사용 중인 주문·상품·QR·공지·문의의 명확한 URL/HTTP Method 불일치는 확인되지 않았다. React API 단위 테스트도 통과했다. 다만 아래 계약 불일치와 수명주기 공백은 확인됐다.

| Frontend 파일 | Backend 파일 | 문제 | 예상 증상 | 수정 방향 |
|---|---|---|---|---|
| `mobile_flutter/packages/app_core/lib/src/auth/auth_session.dart` | `backend_spring/src/main/java/com/example/project_popq/auth/dto/AuthTokenResponse.java` | Flutter 모델은 `refreshToken` 필수, Backend 응답에는 없음. 앱이 빈 문자열 저장 | Access Token 만료 후 모든 인증 요청 실패, 자동 복구 불가 | Refresh Token 정식 계약을 추가하거나 클라이언트 모델에서 거짓 필드를 제거 |
| `mobile_flutter/packages/app_core/lib/src/network/popq_api_client.dart` | `backend_spring/src/main/java/com/example/project_popq/auth/config/SecurityConfig.java` | 401을 예외로만 전달하고 갱신/세션 초기화 interceptor 없음 | 사용자가 여러 화면에서 반복 오류를 보고 수동 로그아웃 필요 | 단일 재발급 시도, 실패 시 세션 삭제·로그인 복귀 |
| `web_react/seller-web/src/services/api.ts` | `GlobalExceptionHandler.java`, `ApiError.java` | Web API client가 상태·error code를 버리고 일반 `Error`만 생성 | 401/403/409 구분 불가, 공통 세션 복구 불가 | typed API error와 전역 401/403 처리 추가 |
| `docs/api/ORDER_PAYMENT_API.md` 및 Web/Flutter 환불 UI | `SellerRefundService.java` | 문서는 MVP 전액 환불만 명시하지만 Backend는 잔여 금액 이하 부분 환불 허용 | 클라이언트·운영 정책과 서버 허용 범위 불일치 | 전액 전용으로 제한하거나 부분 환불 계약·UI·회계 규칙을 공식화 |
| Flutter Push 등록 코드 | `FirebaseAdminConfig.java`, `docker-compose.yml` | 클라이언트는 토큰을 등록하지만 Docker는 Firebase enable/ADC 전달이 없음 | DB에는 토큰이 쌓여도 실제 푸시는 Logging Gateway에서 생략 | 배포 secret mount와 환경별 enable 설정 추가 |
| 고객 홈 UI | 전용 Backend API 없음 | 추천·이벤트·랭킹을 임시 데이터로 표시 | 운영 데이터와 화면이 다르고 API 장애가 가려짐 | 전용 API를 정의하거나 운영 빌드에서 임시 섹션 제거 |

## 9. 버그 가능성

- **Critical, 확인됨:** 이메일·전화번호만 알면 비밀번호 변경 가능.
- **High, 확인됨:** Seller 검증 상태 없이 역할 연결·스토어 생성 가능.
- **High, 확인됨:** Backend 테스트 코드 컴파일 불가로 회귀 방어가 현재 중단됨.
- **High, 추정:** 주문 목록 DTO 변환 중 LAZY `store/items/statusHistories/product/options` 순회로 N+1 및 큰 응답 발생 가능. `OrderRepository.java`, `OrderResponse.java`.
- **High, 추정:** PG 호출 중 DB 잠금 유지와 timeout 부재로 결제 병목·교착 대기 가능. `PaymentService.java`, `SellerRefundService.java`, `TossPaymentProvider.java`.
- **Medium, 확인됨:** 홈 API 실패 시 임시 콘텐츠를 표시하여 장애와 정상 빈 상태를 혼동할 수 있다.
- **Medium, 확인됨:** 판매자 Web 토큰을 포함한 연결 객체가 `sessionStorage`에 평문 저장되고 CSP가 없다. XSS 발생 시 토큰 탈취 영향이 커진다.
- **Medium, 확인됨:** 이미지 업로드는 magic byte와 크기만 검사한다. 디코딩, 픽셀 수, 재인코딩, 악성 파일 검사가 없다.
- **Medium, 확인됨:** `SocialAuthService`가 검증 예외를 `System.err`와 stack trace로 직접 출력한다. 외부 라이브러리 메시지에 토큰 일부가 포함될 가능성을 제거해야 한다.
- **Low, 확인됨:** E2E 실행 결과 파일이 Git 추적 대상이라 테스트 때마다 working tree가 변경된다.

## 10. 보안 문제

| 심각도 | 판단 | 근거 | 권장 조치 |
|---|---|---|---|
| Critical | 비밀번호 재설정 본인확인 부재 | `AuthService.resetPassword`가 email+phone 조회 후 즉시 변경 | 기능 공개 중지, OTP/일회용 reset token·만료·rate limit 구현 |
| Critical | 모바일 비밀값 Git 추적 및 앱 내 포함 | `mobile_flutter/config/common.dev.env`, `customer.dev.env` | 즉시 키 폐기/회전, Git 이력 점검, 모바일에 client secret을 두지 않음 |
| High | 판매자 승인 우회 | `connectSellerAccess`, `StoreApplicationService.create` | VERIFIED 상태 또는 승인된 신청만 운영 API 허용 |
| High | Refresh Token/세션 폐기 부재 | Access Token만 발급 | Refresh Token 회전·저장·로그아웃 폐기·재사용 탐지 |
| High | 스키마 변경 책임 이중화 | Flyway + `ddl-auto:update` | 운영 `validate`, 마이그레이션만 변경 허용 |
| Medium | 업로드 권한·파일 검증 부족 | 모든 SELLER/ADMIN이 스토어 귀속 없이 업로드 가능 | storeId 귀속, quota, 실제 이미지 디코딩/재인코딩, 객체 저장소 |
| Medium | 공개 Swagger | `/swagger-ui/**`, `/v3/api-docs/**` permitAll | 운영에서 비활성 또는 관리자/내부망 제한 |
| Medium | 웹 보안 헤더 부족 | `deploy/nginx-spa.conf`에 CSP/HSTS/Permissions-Policy 없음 | 도메인/TLS 확정 후 CSP·HSTS·Permissions-Policy 추가 |
| Medium | 인증/결제 rate limit 없음 | 관련 filter/dependency 없음 | 로그인·재설정·결제·QR session에 제한/감사 적용 |
| Low | FCM 데이터 로그 | 성공/대체 Gateway가 payload data 기록 | 주문 식별자 최소화, 운영 로그 마스킹 |

현재 코드에서 SQL 문자열 결합 기반 SQL Injection은 확인되지 않았다. Repository/JPQL은 바인딩 파라미터를 사용한다. 주문 금액은 서버에서 상품·옵션을 재조회해 계산하며 클라이언트 금액을 신뢰하지 않는 점은 양호하다. StoreMember와 주문 소유권 검증도 주요 서비스에 적용되어 있다.

## 11. 불필요 파일 / 코드 삭제 후보

삭제는 수행하지 않았다.

### 후보 1

- 파일: `docker`
- 판단: 삭제 후보
- 근거: 루트의 0바이트 파일이며 Docker 구성은 `docker-compose.yml`, 각 Dockerfile, `deploy/`가 담당한다.
- 실제 참조 여부: **확인됨 — 저장소 텍스트 참조 없음**
- 삭제 위험도: 낮음
- 권장 조치: 팀 확인 후 삭제.

### 후보 2

- 파일: `web_react/src`, `web_react/public`, `web_react/package.json`, `web_react/package-lock.json`
- 판단: CRA 기본 템플릿/이전 버전 삭제 후보
- 근거: 실제 배포는 `web_react/popq`, `web_react/seller-web` Dockerfile을 사용한다. 루트 CRA는 `react-scripts` 설치가 없어 test/build도 실행되지 않았다.
- 실제 참조 여부: **확인됨 — Docker·문서 실행 경로에서 미사용**
- 삭제 위험도: 중간
- 권장 조치: 필요한 코드가 없는지 팀 확인 후 디렉터리 단위 정리.

### 후보 3

- 파일: `mobile_flutter/lib`, `mobile_flutter/test`, `mobile_flutter/web`, `mobile_flutter/windows`, 루트 `pubspec.yaml`
- 판단: 초기 Flutter 템플릿/이전 단일 앱 삭제 후보
- 근거: 실제 앱은 `apps/customer_app`, `apps/seller_app`, 공유 코드는 `packages/`에 있다. 루트 `main.dart`는 `Flutter Demo`다.
- 실제 참조 여부: **확인됨 — 앱 pubspec의 path dependency와 실행 문서에서 미사용**
- 삭제 위험도: 중간
- 권장 조치: Windows/Web 단일 앱 빌드 계획 유무 확인 후 정리.

### 후보 4

- 파일: `.idea/` 전체, 특히 `.idea/shelf/**`, `*.iml`
- 판단: Git 추적 해제 후보
- 근거: 사용자/IDE별 파일과 shelved patch가 포함돼 충돌·과거 코드 노출 위험이 있다.
- 실제 참조 여부: **확인됨 — 빌드 미사용**
- 삭제 위험도: 낮음
- 권장 조치: 보존이 필요한 shelf를 개인 백업 후 Git 추적 해제, `.gitignore` 추가.

### 후보 5

- 파일: `web_react/popq/test-results/.last-run.json`
- 판단: Git 추적 해제 후보
- 근거: Playwright 실행 결과물이며 실행 때 변경된다.
- 실제 참조 여부: **확인됨 — 테스트 소스/빌드에서 미참조**
- 삭제 위험도: 낮음
- 권장 조치: 추적 해제 후 `**/test-results/`, `**/playwright-report/` ignore.

### 후보 6

- 파일: `mobile_flutter/apps/*/lib/src/features/common/*placeholder*.dart`
- 판단: Dead Code 삭제 후보
- 근거: 클래스 정의 외 참조가 없다.
- 실제 참조 여부: **확인됨 — `rg` 기준 정의 파일만 검색됨**
- 삭제 위험도: 낮음
- 권장 조치: 향후 placeholder 정책이 없으면 삭제.

### 후보 7

- 파일: `mobile_flutter/packages/app_core/README.md`, `design_system/README.md`, 각 `CHANGELOG.md`
- 판단: 자동 생성 템플릿 교체 후보
- 근거: TODO와 sample 문구가 그대로 남아 실제 패키지 계약을 설명하지 않는다.
- 실제 참조 여부: 문서 참조만 가능, 빌드 미사용
- 삭제 위험도: 낮음
- 권장 조치: 삭제보다 실제 사용법·버전 변경 이력으로 교체.

### 후보 8

- 파일: Backend Querydsl, Thumbnailator, OAuth2 Client 의존성
- 판단: 사용되지 않는 dependency 후보
- 근거: `build.gradle`에 선언됐으나 main/test 소스에서 관련 API 사용을 찾지 못했다.
- 실제 참조 여부: **확인됨 — 정적 검색상 없음**
- 삭제 위험도: 중간
- 권장 조치: 향후 구현 계획 확인 후 dependency audit PR에서 제거.

권장 `.gitignore` 추가 후보: `.idea/`, `*.iml`, `**/test-results/`, `**/playwright-report/`, `mobile_flutter/config/*.env`(단 `*.env.example` 예외), 플랫폼별 비밀 설정 파일. 이미 추적된 파일은 ignore 추가만으로 제거되지 않으므로 별도 추적 해제와 키 회전이 필요하다.

## 12. 리팩터링 후보

리팩터링은 수행하지 않았다.

- 3,498줄 `seller_store_registration_screen.dart`, 2,644줄 `customer_home_screen.dart`, 2,130줄 `seller_customer_chat_screen.dart`, 2,062줄 `seller_operation_screen.dart`, 2,005줄 `store_discovery_screen.dart`를 화면 섹션·form controller·mapper로 분리.
- 1,452줄 Seller Web `App.tsx`와 1,121줄 QR Web `App.tsx`에서 인증/저장소/화면 상태/데모 로직을 feature hook과 route 단위로 분리.
- Customer/Seller PushNotificationService가 거의 동일하므로 공통 패키지로 통합. 단 채널명·딥링크 정책은 앱별 주입.
- Flutter 각 Repository의 API DTO 파싱과 Memory 구현을 별도 파일로 분리해 production/test 경계를 명확히 함.
- Backend `CatalogService`(701줄), `StoreApplicationService`(700줄), `OrderMessageService`(692줄)의 조회·명령·권한·매핑 책임 분리.
- Seller/Customer Web API client의 envelope/error 처리 공통화.
- 상태 label/enum mapping이 Web·Flutter 여러 파일에 반복되므로 계약 테스트 가능한 공통 명세 생성.
- Controller는 대체로 얇고 DTO를 사용하며 Entity 직접 노출은 확인되지 않아 이 부분은 양호하다.

## 13. 성능 최적화 후보

### 실제 문제가 될 가능성이 높은 항목

- 주문/고객 주문/판매자 주문/관리자/공지/관심 목록의 pagination 부재.
- `OrderResponse.from`이 주문별 items, statusHistories, item.product, item.options, option.productOption을 순회하지만 목록 Repository의 EntityGraph가 불완전하거나 없다.
- 관리자 overview가 users/sellers/stores를 전부 `findAll()`한 뒤 메모리에서 집계한다. DB count 쿼리로 변경 필요.
- 실제 PG 승인/취소를 DB 트랜잭션 내부에서 호출하며 HTTP timeout 설정이 보이지 않는다.
- Store 목록 매핑 중 일정 조회를 개별 호출해 N+1 가능성이 있다. `StoreApplicationService.java`.
- 대형 Flutter 화면에서 많은 로컬 `setState`와 전체 Widget 재구성이 발생할 가능성. 프로파일링 후 섹션 단위 분리.
- 업로드 원본 이미지를 그대로 저장·제공한다. Thumbnailator 의존성은 있으나 실제 리사이징/재인코딩에 사용되지 않는다.

### 코드 스타일/유지보수 개선

- 긴 파일·함수 분리, 중복 enum label mapper, 중복 Push 서비스, Memory/API Repository 파일 분리.
- Root 템플릿과 실제 앱의 중복 프로젝트 구조 정리.
- 사용하지 않는 dependency/import는 lint·dependency analyzer를 CI에 추가한 뒤 제거.

## 14. 테스트 부족 영역

### 이번 실행 결과

| 대상 | 결과 | 상세 |
|---|---|---|
| Backend `test` | **FAIL** | `PaymentServiceTests.java:73`에서 `PaymentProvider`를 `PaymentProviderRegistry`로 변환할 수 없어 `compileTestJava` 실패 |
| Backend `build` | **FAIL/완료 불가** | `build`가 동일 테스트 컴파일 단계에 의존한다. 별도 재시도에서는 Gradle wrapper 네트워크 접근도 차단됨 |
| Flutter `analyze` | **환경/도구 정지로 실행 불가** | 루트 120초, customer app `--no-pub` 180초 모두 출력 없이 timeout |
| Flutter `test` | **환경/도구 정지로 실행 불가** | app_core `--no-pub` 120초 출력 없이 timeout |
| QR Web lint | **PASS** | ESLint 오류 없음 |
| QR Web test | **PASS** | 4 files, 17 tests |
| QR Web production build | **PASS** | Vite build 성공 |
| QR Web E2E | **PASS(제한적)** | Playwright 2 tests, 모두 데모 모드 |
| Seller Web lint | **PASS** | ESLint 오류 없음 |
| Seller Web test | **PASS** | 6 files, 37 tests |
| Seller Web production build | **PASS** | Vite build 성공 |
| 루트 CRA Web | **FAIL/의존성 미설치** | `react-scripts`를 찾지 못함. 실제 배포 프로젝트가 아닌 삭제 후보 |
| Docker 통합 E2E | **실행 불가** | Backend 컴파일 실패와 운영 DB/외부 설정 부재. 설정을 임의 변경하지 않음 |

### 부족한 시나리오

- 실제 MySQL+Spring+QR Web+Seller Web 주문 생성→결제→접수→완료 교차 E2E.
- 다른 판매자/storeId, 다른 고객/orderPublicId, 관리자 권한의 부정 테스트 자동화 확대.
- 비밀번호 재설정·rate limit·토큰 만료/갱신·로그아웃 폐기 테스트.
- Toss 통신 timeout, 응답 유실, 승인 성공 후 DB 실패, webhook 재전송 테스트.
- Firebase 포그라운드/백그라운드/종료·토큰 갱신·기기 재귀속 실기기 테스트.
- Flutter에는 customer 2개, seller 1개 테스트 파일만 있어 화면 규모에 비해 회귀 범위가 작다.
- 접근성, 작은 화면, 키보드, 네트워크 전환, 앱 복귀, 메모리/성능 테스트.

## 15. 외부 서비스 연동 대기 항목

| 항목 | 현재 분류 | 근거/남은 조건 |
|---|---|---|
| Firebase Auth | 외부 설정 필요 | Flutter SDK와 Google 로그인 코드/Android 설정은 있으나 환경 분리·실계정 검증 필요 |
| FCM | 외부 설정 필요 | Client 수신·등록과 Server Gateway 존재, ADC/서비스 계정·Docker 전달·실기기 검증 필요 |
| Kakao/Naver OAuth | 내부 구현 완료 + 외부 운영 검증 필요 | Client SDK/Backend verifier 존재. 현재 추적된 값 회전과 콘솔 설정·심사 필요 |
| Toss PG | 외부 설정·정책 필요 | 실제 Provider/Client 코드 존재. 계약·키·webhook·대사·환불 정책 필요 |
| 리뷰 이미지 저장소 | 정책 결정 필요 | 텍스트 리뷰만 완료. object storage·제한·검수·삭제 필요 |
| 일반 이미지 업로드 | 현재 내부 구현 완료 | 로컬 volume 저장. 운영 object storage/CDN·보안 검증 필요 |
| 정산 | 완전 미구현/정책 결정 필요 | 원장·주기·공제·세무·지급 정책 없음 |
| 공지 | 판매자 내부 구현 완료 | 고객/QR 노출·예약·만료 정책 대기 |
| 지도/주소 검색 | 부분 운영 가능 | Kakao 연동 코드 존재. 키 관리·쿼터·장애 fallback 정책 필요 |

## 16. 문서와 실제 코드가 다른 부분

- `README.md`는 프로젝트 전체 소개가 아니라 최근 고객 홈/마이페이지 UI 변경 내역만 설명한다. 설치·구조·현재 위험·검증 명령의 단일 진입점 역할을 못 한다.
- `FLUTTER_PHASE9_PLAN.md`는 Firebase 설정 대기라고 적지만 현재 두 Android `google-services.json`, Flutter Firebase 초기화/메시징/기기 등록 코드가 있다. 서버 운영 자격증명은 여전히 대기다.
- `EXTERNAL_INTEGRATION_BACKLOG.md`의 “공지 미착수”는 오래됐다. Announcement migration/API와 Seller Web/Flutter UI가 구현됐다.
- `SELLER_CHANNEL_STATUS_REPORT_2026-07-29.md`의 “Web 수동 Store ID+Token”, “공지/고객 메시지 API 없음”은 현재 코드와 다르다. Web 로그인·스토어 선택, 공지, Order Message API/UI가 있다.
- `WEB_FOLLOW_UP_BACKLOG.md`의 WEB-01은 일부 완료됐다. Email login·스토어 선택은 구현됐지만 Refresh Token/공통 401은 남았다.
- 같은 백로그의 WEB-09는 공지와 기본 고객 문의가 구현돼 범위 재작성 필요.
- `ORDER_PAYMENT_API.md`는 전액 환불만 허용한다고 쓰지만 Backend는 부분 환불 금액을 허용한다.
- `docs/api`에는 Auth, Seller Review, Seller Push Device, Order Message, Store Image, Store Schedule/확장 Store API 문서가 없다.
- `docs/DEPLOYMENT.md`는 Firebase 서버 활성화와 ADC 전달 방법을 설명하지 않고 `docker-compose.yml`도 관련 환경변수를 전달하지 않는다.
- `FLUTTER_PHASE9_PLAN.md`의 과거 테스트 통과 수치는 현재 상태 증거가 아니다. 이번 점검에서 Backend 테스트 컴파일이 실패했다.

## 17. 우선순위

### P0

- [ ] `PaymentServiceTests`를 현재 `PaymentProviderRegistry` 생성자 계약에 맞춰 Backend test/build 복구.
- [ ] 비밀번호 재설정 API를 OTP/일회용 토큰 기반으로 재설계하기 전 공개 비활성화.
- [ ] Git 추적 중인 Naver 성격의 secret·외부 키를 폐기/회전하고 모바일 번들에서 client secret 제거.
- [ ] `mobile_flutter/config/*.env`, IDE shelf, 테스트 결과물의 Git 추적 정책 정리와 secret history scan.
- [ ] 운영 Hibernate를 `ddl-auto: validate`로 고정하고 Flyway 단일 변경 책임 확립.
- [ ] SELLER 역할 연결·스토어 생성에 판매자 신청/VERIFIED 정책 적용.
- [ ] Refresh Token 및 Web/Flutter 공통 401 복구 계약 확정.

### P1

- [ ] 실제 MySQL/Spring/QR/Seller 주문 교차 E2E 구축.
- [ ] Toss timeout·webhook·대사·장애 복구·환불 범위 확정.
- [ ] Firebase 서버 자격증명과 환경별 프로젝트 연결, 실기기 FCM 검증.
- [ ] Seller Flutter QR/테이블 운영 구현.
- [ ] StoreMember 초대·역할 관리 및 Admin 감사 로그.
- [ ] 고객 홈 임시 콘텐츠의 API 계약 또는 운영 제거 결정.
- [ ] 공지 고객 노출과 채팅 보존/신고 정책 확정.

### P2

- [ ] 주문·관리자·공지·관심·리뷰 목록 pagination.
- [ ] 주문 DTO EntityGraph/조회 projection으로 N+1 제거.
- [ ] 대형 Flutter Widget와 두 Web `App.tsx` 분리.
- [ ] 중복 Push 서비스·상태 label·API error 처리 공통화.
- [ ] 이미지 재인코딩·리사이징·quota와 object storage 준비.
- [ ] CI에 Backend/Flutter/React lint·test·build·E2E·secret scan 추가.
- [ ] 접근성·반응형·실기기 QA.

### P3

- [ ] 정산 원장·지급·세무·내보내기.
- [ ] 운영 관측성, 제품 분석, 추천 고도화.
- [ ] 다중 Backend용 broker relay/outbox/Redis 검토.
- [ ] 부분 환불·보상 처리 자동화와 관리자 운영 도구.

## 18. 다음 개발 단계 추천

1. Backend 테스트 생성자 불일치를 고쳐 전체 test/build를 다시 통과시킨다.
2. 노출된 외부 키를 회전하고 Git 추적/모바일 secret 정책을 정리한다.
3. 비밀번호 재설정과 판매자 승인 경계를 먼저 막고 보안 회귀 테스트를 추가한다.
4. Access/Refresh Token 계약과 401/403 처리 표준을 Backend·Flutter·Web에 동시에 적용한다.
5. 운영 DB는 Flyway+`validate`로 고정하고 신규 환경에서 빈 DB migration smoke test를 만든다.
6. Docker 통합 스택에서 QR 주문→결제(TEST)→판매자 처리→고객 동기화 E2E를 만든다.
7. 실제 Toss 연동의 timeout, webhook, 대사, 장애 복구를 구현·검증한다.
8. Firebase 배포 설정과 소비자/판매자 실기기 알림을 검증한다.
9. Seller Flutter QR/테이블과 StoreMember 관리 중 운영 우선순위를 선택해 구현한다.
10. pagination/N+1과 대형 UI 파일을 기능 안정화 후 단계적으로 정리한다.

## 19. 팀 작업 분배 추천

- **Backend:** 테스트 복구, 비밀번호 재설정, Refresh Token, 판매자 승인 게이트, pagination/N+1, PG webhook/timeout.
- **Flutter Customer:** 401 복구, 임시 홈 데이터 정책, 결제/FCM 실기기 QA, 리뷰 이미지 준비.
- **Flutter Seller:** 401 복구, QR/테이블 운영, FCM 실기기 QA, 대형 운영/등록 화면 분리.
- **Web:** typed API error와 401/403 복구, 데모 운영 노출 정책, Seller Web 접근성·E2E, CSP 호환 정리.
- **Infra/Integration:** 키 회전·secret scan, Flyway 운영 정책, Docker 통합 E2E, Firebase ADC, Toss 운영 구성, CI.

병렬 진행 조건: Backend가 인증/오류/pagination 계약을 먼저 짧은 API 문서로 고정하고, 각 Client가 같은 계약 브랜치 기준으로 작업한다. 결제·비밀번호·권한은 Client 단독 구현을 금지하고 Backend 보안 테스트와 함께 완료 처리한다.

## 20. 최종 체크리스트

- [ ] Backend `test`와 `build`가 현재 브랜치에서 통과한다.
- [ ] 비밀번호 재설정에 OTP/일회용 토큰·만료·시도 제한이 있다.
- [ ] 추적된 외부 키를 모두 회전했고 값이 Git/모바일 번들에 남지 않는다.
- [ ] Secret scanner가 현재 트리와 Git 이력을 검사한다.
- [ ] Refresh Token 발급·회전·폐기·로그아웃이 동작한다.
- [ ] Web/Flutter가 401 한 번 갱신 후 실패 시 로그인으로 복귀한다.
- [ ] 403은 세션 만료와 구분해 권한 안내를 제공한다.
- [ ] SELLER 운영 API가 승인 정책을 검증한다.
- [ ] 운영 `ddl-auto`가 `validate`이며 Flyway만 스키마를 변경한다.
- [ ] QR→주문→결제→판매자 처리→고객 상태 복구 E2E가 실제 Backend/DB로 통과한다.
- [ ] Toss timeout·webhook 서명·대사·중복 이벤트 테스트가 있다.
- [ ] Firebase 소비자/판매자 실기기 송수신과 토큰 갱신이 검증됐다.
- [ ] 주문·관리자·공지·관심·리뷰 목록에 pagination과 최대 size가 있다.
- [ ] StoreMember 타 스토어 IDOR 부정 테스트가 있다.
- [ ] 이미지 업로드에 귀속·quota·디코딩·리사이징 검증이 있다.
- [ ] Seller Flutter QR/테이블 운영 범위가 결정·구현됐다.
- [ ] 고객 홈 임시 콘텐츠가 운영 API 또는 명시적 빈 상태로 교체됐다.
- [ ] `docs/api`가 현재 Auth/Message/Review/Push/Image API를 포함한다.
- [ ] README가 전체 구조·실행·검증·현재 외부 의존성을 안내한다.
- [ ] `.idea`, test-results, legacy root templates의 삭제/추적 해제를 팀이 승인했다.
- [ ] CI가 Backend/Flutter/React lint·test·build와 핵심 E2E를 실행한다.
- [ ] 접근성·작은 화면·네트워크 전환·앱 재실행 QA가 완료됐다.

## 마지막 요약

### 현재 프로젝트에서 가장 위험한 문제 5개

1. 비밀번호 재설정 계정 탈취 가능성.
2. Git 추적 모바일 외부연동 secret/키.
3. Backend 테스트 컴파일 실패.
4. 판매자 승인 우회와 Refresh Token 부재.
5. Flyway와 Hibernate 자동 스키마 변경 병용.

### 아직 구현되지 않은 핵심 기능 5개

1. 안전한 비밀번호 재설정.
2. Refresh Token/세션 회전.
3. Seller Flutter QR/테이블 운영.
4. 실제 통합 E2E/CI.
5. 정산 및 감사 로그.

### 가장 먼저 정리할 코드/파일 5개

1. `PaymentServiceTests.java`의 오래된 생성자 사용.
2. `mobile_flutter/config/*.dev.env`의 추적 비밀값.
3. `.idea/shelf/**`와 IDE 파일.
4. 루트 legacy `web_react/src`와 `mobile_flutter/lib` 템플릿.
5. `web_react/popq/test-results/.last-run.json`.

### 다음 개발 작업 10개

1. Backend build 복구.
2. 외부 키 회전.
3. 비밀번호 재설정 차단/재설계.
4. 판매자 승인 게이트.
5. Refresh Token/401 처리.
6. Flyway 운영 정책.
7. 실제 주문 통합 E2E.
8. Toss 운영 안정화.
9. Firebase 실기기 연결.
10. pagination/N+1 및 CI 정리.
