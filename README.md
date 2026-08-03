# 판매자/고객 이메일·비밀번호 로그인, 회원가입 추가

개발용 로그인과 소셜 로그인 버튼만 있던 판매자 앱(`seller_app`)에 실제 이메일/비밀번호 인증을 추가했고, 고객 앱(`customer_app`)에도 동일한 방식으로 추가했습니다.

## 백엔드 (`backend_spring`)

- `POST /api/v1/auth/signup`, `POST /api/v1/auth/login` 신규 API 추가 (`role`로 SELLER/CUSTOMER 구분)
- `auth/service/AuthService.java` (신규) — 이메일 중복 확인 → BCrypt 해시 저장 → SELLER면 SellerProfile 자동 생성 → JWT 발급
- `auth/dto/SignupRequest.java`, `LoginRequest.java`, `AuthTokenResponse.java` (신규)
- `user/domain/User.java` — `passwordHash`를 받는 `createWithPassword()` 팩토리 추가 (기존 `create()`는 유지)
- `auth/config/SecurityConfig.java` — `PasswordEncoder`(BCrypt) 빈 추가, signup/login 경로 공개 처리
- `common/error/ErrorCode.java` — `INVALID_CREDENTIALS`(401) 추가
- `db/migration/V9__add_password_hash_to_users.sql` — `users` 테이블에 `password_hash` 컬럼 추가
- `test/auth/AuthSignupLoginIntegrationTests.java` (신규) — 가입/로그인/중복이메일/약한비밀번호/오답비밀번호/미존재이메일 통합 테스트

## 판매자 앱 (`mobile_flutter/apps/seller_app`)

- `features/auth/seller_auth_repository.dart` (신규) — signUp()/logIn() API 연동
- `features/auth/seller_sign_up_screen.dart` (신규) — 회원가입 화면
- `features/auth/seller_sign_in_screen.dart` — 이메일/비밀번호 로그인 폼과 "로그인" 버튼, 회원가입 이동 링크 추가 (기존 개발용 로그인·소셜 버튼은 유지)
- `routing/seller_router.dart` — `/sign-up` 라우트 추가
- `seller_app.dart` — `_signIn`/`_signUp` 추가해 라우터에 연결 (가입/로그인 성공 시 세션 저장 후 대시보드로 이동, 자동 스토어 생성 없음)
- `test/widget_test.dart` — 로그인/회원가입 위젯 테스트 추가

## 고객 앱 (`mobile_flutter/apps/customer_app`)

- `features/auth/customer_auth_repository.dart` (신규) — signUp()/logIn() API 연동
- `features/auth/customer_sign_up_screen.dart` (신규) — 회원가입 화면
- `features/auth/sign_in_screen.dart` — 이메일/비밀번호 로그인 폼과 "로그인" 버튼, 회원가입 이동 링크 추가 (기존 Google/Kakao/Naver 버튼, 개발용 로그인, 장바구니 모달 로그인 흐름은 유지)
- `routing/customer_router.dart` — `/sign-up` 라우트 추가
- `customer_app.dart` — `_signIn`/`_signUp` 추가해 라우터에 연결
- `features/cart/cart_screen.dart` — 장바구니에서 뜨는 로그인 모달에도 이메일 로그인 연결
