# 기본 관리자 API

React 판매자 웹 내부의 역할 분리 관리자 모듈이 사용하는 API다. 모든 경로는 Bearer Access Token이 필요하며 `ADMIN` 플랫폼 역할만 접근할 수 있다. 컨트롤러와 서비스 계층에서 권한을 각각 검증한다.

## 현황과 목록

| Method | Path | 설명 |
|---|---|---|
| GET | `/api/v1/admin/overview` | 사용자·판매자·스토어 주요 건수 |
| GET | `/api/v1/admin/users` | 전체 사용자 목록 |
| GET | `/api/v1/admin/sellers` | 판매자 프로필과 인증 상태 |
| GET | `/api/v1/admin/stores` | 전체 스토어와 운영 상태 |

현황 응답에는 전체·활성 사용자, 전체·인증 대기 판매자, 전체·활성·정지 스토어 수가 포함된다.

## 사용자 상태

```text
PATCH /api/v1/admin/users/{userId}/status
```

```json
{
  "status": "SUSPENDED"
}
```

지원 상태는 `ACTIVE`, `SUSPENDED`, `WITHDRAWN`이다. 현재 로그인한 관리자는 자신의 계정을 `SUSPENDED` 또는 `WITHDRAWN`으로 변경할 수 없다. 기본 화면은 복구 가능한 `ACTIVE ↔ SUSPENDED` 전환만 제공한다.

## 판매자 인증

```text
PATCH /api/v1/admin/sellers/{sellerProfileId}/verification
```

```json
{
  "verificationStatus": "VERIFIED"
}
```

지원 상태는 `PENDING`, `VERIFIED`, `REJECTED`다.

## 스토어 상태

```text
PATCH /api/v1/admin/stores/{storeId}/status
```

```json
{
  "status": "SUSPENDED"
}
```

지원 상태는 `ACTIVE`, `SUSPENDED`, `CLOSED`다. 기본 화면은 `ACTIVE ↔ SUSPENDED` 전환을 제공하며 `CLOSED` 스토어는 목록에서 확인만 한다.

## 보안 원칙

- 판매자·고객 토큰은 모든 관리자 서비스에서 `ACCESS_DENIED`로 거부한다.
- 관리자 자신의 계정 정지를 서버에서 차단한다.
- 상태 변경 대상이 없으면 도메인별 `NOT_FOUND` 오류를 반환한다.
- 화면에서 숨기거나 버튼을 비활성화하는 것과 관계없이 최종 권한 판단은 서버가 수행한다.
