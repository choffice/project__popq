# 판매자/고객 이메일·비밀번호 로그인, 회원가입 추가

개발용 로그인과 소셜 로그인 버튼만 있던 판매자 앱(`seller_app`)에 실제 이메일/비밀번호 인증을 추가했고, 고객 앱(`customer_app`)에도 동일한 방식으로 추가했습니다. 이후 전화번호 필수 입력 및 중복 확인, 아이디/비밀번호 찾기, 회원가입 후 자동 로그인 제거, 데이터 이용 동의 체크박스를 이어서 추가했습니다.

## 백엔드 (`backend_spring`)

- `POST /api/v1/auth/signup`, `POST /api/v1/auth/login` — 최초 로그인/회원가입 API (`role`로 SELLER/CUSTOMER 구분)
- `POST /api/v1/auth/find-id` (신규) — 이름+전화번호로 가입된 이메일을 마스킹해서 반환
- `POST /api/v1/auth/password-reset/verify` (신규) — 이메일+전화번호로 본인 확인
- `POST /api/v1/auth/password-reset/confirm` (신규) — 확인 후 새 비밀번호로 변경
- `auth/service/AuthService.java` — 이메일/전화번호 중복 확인 → BCrypt 해시 저장 → SELLER면 SellerProfile 자동 생성 → JWT 발급 (`signup`); `findId`, `verifyForPasswordReset`, `resetPassword` 메서드 추가; 전화번호 정규화(`-` 제거), 이메일 마스킹 유틸 포함
- `auth/dto/SignupRequest.java` — `phone`을 선택 입력에서 **필수**(`@NotBlank` + 휴대폰 번호 형식 검증)로 변경
- `auth/dto/FindIdRequest.java`, `FindIdResponse.java`, `PasswordResetVerifyRequest.java`, `PasswordResetConfirmRequest.java`, `AckResponse.java` (모두 신규)
- `user/domain/User.java` — `passwordHash`를 받는 `createWithPassword()` 팩토리, 비밀번호 재설정용 `changePasswordHash()` 추가 (기존 `create()`는 유지)
- `user/repository/UserRepository.java` — `existsByEmailIgnoreCase`, `existsByPhone`, `findByNameAndPhone`, `findByEmailIgnoreCaseAndPhone` 추가
- `auth/config/SecurityConfig.java` — `PasswordEncoder`(BCrypt) 빈 추가, signup/login/find-id/password-reset 경로 공개 처리
- `common/error/ErrorCode.java` — `INVALID_CREDENTIALS`(401), `IDENTITY_VERIFICATION_FAILED`(400), `DUPLICATE_PHONE`(409) 추가
- `db/migration/V9__add_password_hash_to_users.sql` — `users` 테이블에 `password_hash` 컬럼 추가
- `db/migration/V10__add_unique_constraint_to_users_phone.sql` (신규) — `users.phone` 유니크 제약 추가 (전화번호 중복 가입 방지)
- `test/auth/AuthSignupLoginIntegrationTests.java` — 가입/로그인 기본 테스트에 더해 전화번호 중복, 잘못된/누락된 전화번호, 아이디 찾기 성공/실패, 비밀번호 재설정 후 재로그인 등 테스트 추가

## 판매자 앱 (`mobile_flutter/apps/seller_app`)

- `features/auth/seller_auth_repository.dart` — `signUp()`에 `phone` 필수 파라미터 추가, `findId()`/`verifyForPasswordReset()`/`resetPassword()` API 연동 추가
- `features/auth/seller_sign_up_screen.dart` — 전화번호 필수 입력 + 형식 검증 추가; 폼 맨 아래 "데이터 잘 쓸게요" 동의 체크박스 추가(미체크 시 제출 불가); 가입 성공 시 자동 로그인하지 않고 안내 메시지와 함께 로그인 화면으로 이동
- `features/auth/seller_sign_in_screen.dart` — "아이디 찾기 / 비밀번호 찾기" 링크 추가, 버튼 텍스트 "이메일로 로그인" → "로그인"
- `features/auth/seller_find_id_screen.dart` (신규) — 이름+전화번호로 아이디(마스킹된 이메일) 찾기 화면
- `features/auth/seller_find_password_screen.dart` (신규) — 이메일+전화번호 확인 후 새 비밀번호 설정 화면
- `routing/seller_router.dart` — `/find-id`, `/find-password` 라우트 및 로그인 전 화면 리다이렉트 처리 추가
- `seller_app.dart` — `_signUp`이 더 이상 세션을 저장하지 않도록 변경(자동 로그인 제거), `_findId`/`_verifyForPasswordReset`/`_resetPassword` 추가해 라우터에 연결
- `test/widget_test.dart` — 회원가입 후 자동 로그인 없이 로그인 화면으로 돌아가는지, 아이디 찾기, 비밀번호 찾기 흐름에 대한 위젯 테스트 추가

## 고객 앱 (`mobile_flutter/apps/customer_app`)

- `features/auth/customer_auth_repository.dart` — `signUp()`에 `phone` 필수 파라미터 추가, `findId()`/`verifyForPasswordReset()`/`resetPassword()` API 연동 추가
- `features/auth/customer_sign_up_screen.dart` — 전화번호 필수 입력 + 형식 검증 추가; 폼 맨 아래 "데이터 잘 쓸게요" 동의 체크박스 추가(미체크 시 제출 불가); 가입 성공 시 자동 로그인하지 않고 안내 메시지와 함께 로그인 화면으로 이동
- `features/auth/sign_in_screen.dart` — "아이디 찾기 / 비밀번호 찾기" 링크 추가 (기존 Google/Kakao/Naver 버튼, 개발용 로그인, 장바구니 모달 로그인 흐름은 유지)
- `features/auth/customer_find_id_screen.dart` (신규) — 이름+전화번호로 아이디(마스킹된 이메일) 찾기 화면
- `features/auth/customer_find_password_screen.dart` (신규) — 이메일+전화번호 확인 후 새 비밀번호 설정 화면
- `routing/customer_router.dart` — `/find-id`, `/find-password` 라우트 및 로그인 전 화면 리다이렉트 처리 추가
- `customer_app.dart` — `_signUp`이 더 이상 세션을 저장하지 않도록 변경(자동 로그인 제거), `_findId`/`_verifyForPasswordReset`/`_resetPassword` 추가해 라우터에 연결
- `features/cart/cart_screen.dart` — 장바구니 로그인 모달에도 동일한 `onSignIn` 흐름 연결
