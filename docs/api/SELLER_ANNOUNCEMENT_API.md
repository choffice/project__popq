# 판매자 공지사항 API

기준일: 2026-07-30

## 범위

이번 계약은 판매자 내부의 사업장 공지 작성과 게시 상태 관리다.

- `DRAFT`: 작성 중
- `PUBLISHED`: 게시 중
- `HIDDEN`: 숨김

고객 앱·QR 웹 공개 노출, 채널 선택, 예약 게시와 만료는 운영 정책 확정 후 별도 계약으로 확장한다.

## 권한

- 목록 조회: OWNER, MANAGER, STAFF
- 작성·수정·게시·숨김: OWNER, MANAGER
- 모든 요청에서 활성 `StoreMember`와 `{storeId}`를 검증한다.
- 다른 사업장의 공지 ID는 조회하거나 변경할 수 없다.

## 엔드포인트

| Method | Path | 설명 |
|---|---|---|
| GET | `/api/v1/seller/stores/{storeId}/announcements` | 사업장 공지 목록 |
| POST | `/api/v1/seller/stores/{storeId}/announcements` | 공지 초안 작성 |
| PATCH | `/api/v1/seller/stores/{storeId}/announcements/{announcementId}` | 제목·내용 수정 |
| PATCH | `/api/v1/seller/stores/{storeId}/announcements/{announcementId}/status` | 게시 상태 변경 |

## 작성·수정 요청

```json
{
  "title": "여름 운영시간 변경",
  "content": "주말에는 오후 6시에 마감합니다."
}
```

- 제목은 필수이며 최대 200자다.
- 내용은 필수이며 최대 2,000자다.
- 새 공지는 항상 `DRAFT`로 생성된다.

## 게시 상태 변경

```json
{
  "status": "PUBLISHED"
}
```

`PUBLISHED`로 변경할 때 서버가 `publishedAt`을 기록한다.

## Flutter 연결

판매자 앱의 `운영 > 공지사항`에서 목록, 빈 상태, 작성, 수정, 게시와 숨김을 제공한다. STAFF에는 작성·수정·상태 변경 버튼을 노출하지 않는다.

