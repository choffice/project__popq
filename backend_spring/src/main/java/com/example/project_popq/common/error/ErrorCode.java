package com.example.project_popq.common.error;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public enum ErrorCode {
  INVALID_REQUEST(HttpStatus.BAD_REQUEST, "요청 값이 올바르지 않습니다."),
  AUTHENTICATION_REQUIRED(HttpStatus.UNAUTHORIZED, "인증이 필요합니다."),
  INVALID_REFRESH_TOKEN(HttpStatus.UNAUTHORIZED, "유효하지 않거나 만료된 Refresh Token입니다."),
  ACCESS_DENIED(HttpStatus.FORBIDDEN, "접근 권한이 없습니다."),
  RESOURCE_NOT_FOUND(HttpStatus.NOT_FOUND, "요청한 리소스를 찾을 수 없습니다."),
  USER_NOT_FOUND(HttpStatus.NOT_FOUND, "사용자를 찾을 수 없습니다."),
  USER_INACTIVE(HttpStatus.FORBIDDEN, "비활성화된 사용자입니다."),
  DUPLICATE_USER(HttpStatus.CONFLICT, "이미 등록된 사용자입니다."),
  DUPLICATE_PHONE(HttpStatus.CONFLICT, "이미 등록된 전화번호입니다."),
  INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다."),
  INVALID_SOCIAL_TOKEN(
          HttpStatus.UNAUTHORIZED,
          "유효하지 않은 소셜 로그인 토큰입니다."
  ),
  SOCIAL_ROLE_MISMATCH(
          HttpStatus.FORBIDDEN,
          "해당 앱에서 로그인할 수 없는 계정 역할입니다."
  ),
  IDENTITY_VERIFICATION_FAILED(HttpStatus.BAD_REQUEST, "입력하신 정보와 일치하는 계정을 찾을 수 없습니다."),
  WITHDRAWAL_CONFIRMATION_MISMATCH(HttpStatus.BAD_REQUEST, "입력하신 확인 문구가 일치하지 않습니다."),
  INVALID_DEV_ROLE(HttpStatus.BAD_REQUEST, "개발 로그인에서 허용되지 않는 역할입니다."),
  INVALID_SIGNUP_ROLE(HttpStatus.BAD_REQUEST, "공개 회원가입에서 허용되지 않는 역할입니다."),
  SELLER_PROFILE_NOT_FOUND(HttpStatus.NOT_FOUND, "판매자 프로필을 찾을 수 없습니다."),
  STORE_NOT_FOUND(HttpStatus.NOT_FOUND, "스토어를 찾을 수 없습니다."),
  STORE_ACCESS_DENIED(HttpStatus.FORBIDDEN, "스토어 접근 권한이 없습니다."),
  DUPLICATE_STORE_MEMBER(HttpStatus.CONFLICT, "이미 등록된 스토어 멤버입니다."),
  STORE_NOT_OPEN(HttpStatus.CONFLICT, "현재 영업 중인 스토어가 아닙니다."),
  STORE_TABLE_NOT_FOUND(HttpStatus.NOT_FOUND, "스토어 테이블을 찾을 수 없습니다."),
  DUPLICATE_STORE_TABLE(HttpStatus.CONFLICT, "동일한 테이블 코드가 이미 존재합니다."),
  STORE_TABLE_NOT_ALLOWED(HttpStatus.BAD_REQUEST, "해당 스토어 유형은 테이블을 사용할 수 없습니다."),
  CATEGORY_NOT_FOUND(HttpStatus.NOT_FOUND, "상품 카테고리를 찾을 수 없습니다."),
  DUPLICATE_CATEGORY(HttpStatus.CONFLICT, "동일한 카테고리가 이미 존재합니다."),
  PRODUCT_NOT_FOUND(HttpStatus.NOT_FOUND, "상품을 찾을 수 없습니다."),
  INVALID_PRODUCT_OPTION(HttpStatus.BAD_REQUEST, "상품 옵션 구성이 올바르지 않습니다."),
  QR_NOT_FOUND(HttpStatus.NOT_FOUND, "QR을 찾을 수 없습니다."),
  QR_INACTIVE(HttpStatus.GONE, "비활성화된 QR입니다."),
  QR_EXPIRED(HttpStatus.GONE, "만료된 QR입니다."),
  QR_REVOKED(HttpStatus.GONE, "폐기된 QR입니다."),
  QR_STATE_INVALID(HttpStatus.CONFLICT, "허용되지 않는 QR 상태 변경입니다."),
  QR_ARTIFACT_UNAVAILABLE(HttpStatus.CONFLICT, "이 QR은 다시 확인할 수 없어 재발급이 필요합니다."),
  GUEST_SESSION_INVALID(HttpStatus.UNAUTHORIZED, "비회원 세션이 유효하지 않습니다."),
  GUEST_SESSION_EXPIRED(HttpStatus.UNAUTHORIZED, "비회원 세션이 만료되었습니다."),
  ORDER_NOT_FOUND(HttpStatus.NOT_FOUND, "주문을 찾을 수 없습니다."),
  ORDER_ACCESS_DENIED(HttpStatus.FORBIDDEN, "주문 조회 권한이 없습니다."),
  ORDER_EXPIRED(HttpStatus.CONFLICT, "결제 가능 시간이 만료된 주문입니다."),
  ORDER_ITEM_EMPTY(HttpStatus.BAD_REQUEST, "주문 상품이 비어 있습니다."),
  PRODUCT_UNAVAILABLE(HttpStatus.CONFLICT, "현재 주문할 수 없는 상품입니다."),
  OPTION_NOT_FOUND(HttpStatus.BAD_REQUEST, "선택한 상품 옵션을 찾을 수 없습니다."),
  INVALID_OPTION_SELECTION(HttpStatus.BAD_REQUEST, "상품 옵션 선택 조건이 올바르지 않습니다."),
  IDEMPOTENCY_CONFLICT(HttpStatus.CONFLICT, "동일한 멱등성 키에 다른 요청이 전달되었습니다."),
  INVALID_ORDER_STATUS(HttpStatus.CONFLICT, "허용되지 않는 주문 상태 변경입니다."),
  ORDER_CANNOT_CANCEL(HttpStatus.CONFLICT, "현재 상태에서는 주문을 취소할 수 없습니다."),
  REVIEW_NOT_FOUND(HttpStatus.NOT_FOUND, "리뷰를 찾을 수 없습니다."),
  REVIEW_NOT_ALLOWED(HttpStatus.CONFLICT, "완료된 본인 주문만 리뷰를 작성할 수 있습니다."),
  REVIEW_ALREADY_EXISTS(HttpStatus.CONFLICT, "이미 리뷰가 작성된 주문입니다."),
  PUSH_DEVICE_NOT_FOUND(HttpStatus.NOT_FOUND, "푸시 알림 기기를 찾을 수 없습니다."),
  NOTIFICATION_NOT_FOUND(HttpStatus.NOT_FOUND, "알림을 찾을 수 없습니다."),
  ANNOUNCEMENT_NOT_FOUND(HttpStatus.NOT_FOUND, "공지사항을 찾을 수 없습니다."),
  PAYMENT_NOT_FOUND(HttpStatus.NOT_FOUND, "결제 정보를 찾을 수 없습니다."),
  PAYMENT_FAILED(HttpStatus.PAYMENT_REQUIRED, "결제 승인에 실패했습니다."),
  PAYMENT_AMOUNT_MISMATCH(HttpStatus.CONFLICT, "결제 승인 금액이 주문 금액과 일치하지 않습니다."),
  REFUND_NOT_ALLOWED(HttpStatus.CONFLICT, "현재 주문 또는 결제 상태에서는 환불할 수 없습니다."),
  INVALID_REFUND_AMOUNT(HttpStatus.BAD_REQUEST, "환불 금액이 올바르지 않습니다."),
  REFUND_FAILED(HttpStatus.CONFLICT, "환불 처리에 실패했습니다."),
  INSUFFICIENT_POINTS(HttpStatus.CONFLICT, "응모권 구매에 필요한 포인트가 부족합니다."),
  WALKING_ROUTE_UNAVAILABLE(HttpStatus.BAD_GATEWAY, "도보 경로를 불러오지 못했습니다."),
  REVERSE_GEOCODE_UNAVAILABLE(HttpStatus.BAD_GATEWAY, "현재 위치의 주소를 불러오지 못했습니다."),
  KAKAO_API_NOT_CONFIGURED(HttpStatus.SERVICE_UNAVAILABLE,"카카오 API 설정이 필요합니다."),
  KAKAO_LOCATION_UNAVAILABLE(HttpStatus.BAD_GATEWAY, "카카오 위치 정보를 불러오지 못했습니다."),
  INVALID_UPLOAD_FILE(HttpStatus.BAD_REQUEST, "업로드할 이미지 파일이 올바르지 않습니다."),
  UPLOAD_FILE_TOO_LARGE(HttpStatus.PAYLOAD_TOO_LARGE, "업로드 파일 크기가 허용 범위를 초과했습니다."),
  FILE_STORAGE_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, "이미지 파일을 저장하지 못했습니다."),
  SOCIAL_ACCOUNT_ALREADY_LINKED(HttpStatus.CONFLICT, "이미 다른 계정에 연동된 소셜 로그인입니다."),
  INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "서버 내부 오류가 발생했습니다.");


  private final HttpStatus status;
  private final String message;

  ErrorCode(HttpStatus status, String message) {
    this.status = status;
    this.message = message;
  }
}
