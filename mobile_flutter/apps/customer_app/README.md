# POPQ Customer App

회원 소비자용 Android/iOS 앱이다.

현재 완료 범위:

- POPQ 공통 테마
- 홈·탐색·주문·마이 하단 탐색 셸
- 환경별 API 주소 계약
- URL 라우팅과 주문·마이 인증 가드
- 암호화 세션 저장과 복구 실패·재시도
- Bearer API 클라이언트와 공통 로딩·오류·빈 상태
- 최초 실행 온보딩과 완료 상태 저장
- 위치·알림 권한 요청 및 거부·설정 경계
- 공개 스토어 키워드·태그·현재 위치 검색
- 스토어 목록·빈 상태·오류·새로고침과 상세 화면
- 공개 상품 목록과 필수·복수 옵션 선택
- 단일 스토어 장바구니, 수량 변경, 테스트 결제 체크아웃
- 주문·결제 멱등성 재시도와 회원 주문 소유권 계약
- 주문 목록·상세·서버 버전 기반 최신 상태 복구
- 마이 등 이후 단계의 화면 경계

다음 9.4에서는 관심 스토어, 리뷰와 마이페이지를 구현한다.

로컬 Android 에뮬레이터는 기본적으로 `http://10.0.2.2:8082`의 Spring Boot API를 사용한다. 백엔드 없이 UI 흐름을 검증할 때는 위젯 테스트의 `MemoryStoreDiscoveryRepository`, `MemoryCatalogRepository`, `MemoryCustomerOrderRepository`를 사용한다.

현재 결제는 `TestPaymentProvider`다. 실제 PG가 확정되기 전까지 결제 SDK·키·스토어 심사 정보는 추가하지 않는다.

`POPQ_FLAVOR=development`에서는 로그인 화면에 `개발용 고객으로 로그인` 버튼이 나타난다. 로컬 Spring Boot에서 dev 로그인을 활성화했을 때만 동작하며 staging·production 빌드에는 노출되지 않는다.
