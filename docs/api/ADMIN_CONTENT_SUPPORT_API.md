# 관리자 콘텐츠·고객지원 API

## 관리자 목록 공통 규칙

사용자, 판매자, 스토어 목록은 서버 페이지네이션을 사용한다.

- `page`: 0부터 시작
- `size`: 기본 20, 최대 100
- `query`: 이름·이메일·업무 식별자 검색
- 응답: `content`, `page`, `size`, `totalElements`, `totalPages`, `first`, `last`

### 구매자 회원

```text
GET /api/v1/admin/users?role=CUSTOMER&status=ACTIVE&page=0&size=20&query=김고객
```

상태 필터는 `ACTIVE`, `SUSPENDED`, `WITHDRAWAL_PENDING`, `WITHDRAWN`을 지원한다. 관리자 상태 변경은 탈퇴 절차를 우회하지 않도록 `ACTIVE`, `SUSPENDED`만 허용한다.

```text
PATCH /api/v1/admin/users/{userId}/status
```

```json
{
  "status": "SUSPENDED",
  "reason": "운영 정책 위반 확인"
}
```

### 판매자와 스토어

```text
GET /api/v1/admin/sellers?verificationStatus=PENDING&userStatus=ACTIVE&page=0&size=20
GET /api/v1/admin/stores?status=SUSPENDED&page=0&size=20
```

판매자 인증과 스토어 상태 변경 요청에도 최대 500자의 `reason`을 전달한다. 변경은 `admin_audit_logs`에 관리자, 대상, 변경 전후 값, 사유와 함께 기록된다.

## 플랫폼 공지

관리자 API:

```text
GET  /api/v1/admin/content/announcements
POST /api/v1/admin/content/announcements
PUT  /api/v1/admin/content/announcements/{id}
PATCH /api/v1/admin/content/announcements/{id}/status
```

작성·수정 본문:

```json
{
  "audience": "CUSTOMER_APP",
  "title": "서비스 점검 안내",
  "content": "점검 시간 동안 일부 기능이 제한됩니다.",
  "publishStartAt": "2026-08-13T00:00:00Z",
  "publishEndAt": "2026-08-13T03:00:00Z"
}
```

`audience`는 `ALL`, `CUSTOMER_APP`, `SELLER_APP`, 상태는 `DRAFT`, `PUBLISHED`, `HIDDEN`이다.

앱 공개 조회:

```text
GET /api/v1/public/content/announcements?audience=CUSTOMER_APP
GET /api/v1/public/content/announcements?audience=SELLER_APP
```

공개 조회는 게시 상태이고 현재 시각이 게시 시작·종료 범위에 포함되는 공지만 반환한다.

## FAQ

관리자 API:

```text
GET  /api/v1/admin/content/faqs
POST /api/v1/admin/content/faqs
PUT  /api/v1/admin/content/faqs/{id}
PATCH /api/v1/admin/content/faqs/{id}/status
```

작성·수정 본문:

```json
{
  "audience": "ALL",
  "category": "계정",
  "question": "비밀번호는 어떻게 변경하나요?",
  "answer": "계정 설정에서 변경할 수 있습니다.",
  "displayOrder": 10
}
```

앱 공개 조회:

```text
GET /api/v1/public/content/faqs?audience=CUSTOMER_APP
GET /api/v1/public/content/faqs?audience=SELLER_APP
```

## 고객지원 문의

주문 채팅과 별도의 티켓·메시지 저장소를 사용한다.

앱 사용자 API:

```text
POST /api/v1/support/tickets
GET  /api/v1/support/tickets?page=0&size=20
GET  /api/v1/support/tickets/{ticketId}
POST /api/v1/support/tickets/{ticketId}/messages
```

문의 작성 본문:

```json
{
  "requesterType": "CUSTOMER",
  "category": "STORE_VISIBILITY",
  "subject": "가게가 검색되지 않습니다.",
  "content": "앱 검색 결과에서 매장을 찾을 수 없습니다."
}
```

요청자 유형은 `CUSTOMER`, `SELLER`, 카테고리는 `ACCOUNT`, `STORE_VISIBILITY`, `ORDER_PAYMENT`, `OTHER`이다. 요청자는 자기 문의만 조회하고 답변할 수 있다.

관리자 API:

```text
GET   /api/v1/admin/support/tickets
GET   /api/v1/admin/support/tickets/{ticketId}
POST  /api/v1/admin/support/tickets/{ticketId}/messages
PATCH /api/v1/admin/support/tickets/{ticketId}/status
```

문의 상태는 `RECEIVED`, `WAITING_ADMIN`, `WAITING_REQUESTER`, `CLOSED`이다. 종료된 문의에는 사용자와 관리자 모두 새 메시지를 보낼 수 없다.

## 앱 연결 상태

현재 저장소의 `mobile_flutter`는 Flutter 기본 카운터 예제이므로 실제 구매자·판매자 앱 화면에는 연결하지 않았다. 위 공개/인증 API는 앱 코드가 저장소에 추가되면 바로 연동할 수 있는 계약이다.
