# 고객 앱 홈 · 마이페이지 UI 리뉴얼

고객 앱(`customer_app`)의 홈 화면과 마이페이지를 목업 디자인에 맞춰 새로 구성했습니다. 하단 탭 구성, `PopqAppScaffold`, 라우팅 구조 등 기존 틀은 그대로 두고 화면 내부 UI만 다시 짰습니다. 백엔드에 아직 없는 데이터(랭킹, 포인트, 레벨 등)는 기존 코드의 "임시 콘텐츠" 패턴을 그대로 따라 표시했고, 주석에 API 연동 전 임시값이라고 표시해뒀습니다.

## 고객 앱 (`mobile_flutter/apps/customer_app`)

### 홈 화면

- `features/home/customer_home_content.dart` — 검색바 밑 카테고리 라벨, "이번 주 추천 이벤트" 배너용 `CustomerHomeFeatureBanner` 모델 추가; 팝업/추천 항목에 D-day·방문 횟수 필드 추가; 위치 권한 허용 여부에 따라 다른 임시 데이터를 보여주기 위해 권역(수도권/부산)별 팝업·추천 목록 분리
- `features/home/customer_home_controller.dart` — `CustomerPermissionGateway`로 위치 권한을 확인해 현재 위치와 가장 가까운 권역을 판정(허용 안 하면 수도권 기본값), 인기 랭킹·진행 중인 이벤트 데이터를 이 권역 기준으로 필터링/선택하도록 변경
- `features/home/customer_home_screen.dart` — 검색바, 카테고리 탭(전체/식당/팝업스토어/플리마켓/푸드트럭/카페), "이번 주 추천 이벤트" 스와이프 배너, "인기 랭킹 TOP 5"(가로 스크롤, 순위 배지), "진행 중인 이벤트"(가로 스크롤, D-day 배지) 섹션 추가. 기존 진행 중 주문 카드·실제 매장 소개·회원 혜택 배너는 그대로 유지하고 아래로 배치

### 마이페이지

- `features/profile/customer_profile_screen.dart` — 프로필 정보(아바타·이름·레벨·위치)와 활동 통계(찜한 이벤트/참여한 이벤트/방문 횟수/보유 포인트)를 카드 하나로 통합, 메뉴 목록(내 정보/예약 내역/찜한 이벤트/최근 본 이벤트/내 리뷰/포인트 내역/이벤트 참여 내역/알림 설정/고객센터)과 로그아웃·회원 탈퇴 카드로 재구성. 아직 연결된 화면이 없는 메뉴는 탭하면 "준비 중" 스낵바를 띄움. 기존 "화면 설정" 카드는 상단바 토글로 대체되어 삭제
- `features/profile/customer_my_reviews_screen.dart` (신규) — 기존에 마이페이지 안에 있던 리뷰 수정/삭제 로직을 별도 화면(`/my-reviews`)으로 분리
- `features/common/theme_mode_toggle.dart` (신규) — 기본/다크 모드를 전환하는 원형 버튼. 탭하면 같은 자리에서 해 아이콘 ↔ 초승달 아이콘으로 바뀜(슬라이드 아님)
- `customer_root_screen.dart` — 상단바 알림 버튼 왼쪽에 `ThemeModeToggle` 추가 (홈/탐색/QR/찜/마이 5개 탭 공통)
- `routing/customer_router.dart` — `/my-reviews` 라우트 추가(로그인 필요), 홈 화면에 `permissionGateway` 전달, 루트 화면에 `themeController` 전달
