package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.domain.PaymentProviderType;
import com.example.project_popq.payment.provider.KakaoPaymentClient.CancelCommand;
import com.example.project_popq.payment.provider.KakaoPaymentClient.CancelResult;
import com.example.project_popq.payment.provider.KakaoPaymentOrderClient.LookupResult;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class KakaoPaymentProvider implements PaymentProvider {

  private final KakaoPaymentClient kakaoPaymentClient;
  private final KakaoPaymentOrderClient kakaoPaymentOrderClient;

  @Override
  public PaymentProviderType providerType() {
    return PaymentProviderType.KAKAO_PAY;
  }

  /**
   * 카카오페이 승인은 ready 단계에서 저장한 tid와
   * 결제 인증 후 받은 pg_token이 모두 필요합니다.
   *
   * 기존 토스용 공통 승인 Command로는 필요한 값을
   * 안전하게 전달할 수 없으므로 KakaoPaymentService의
   * 전용 승인 API를 사용합니다.
   */
  @Override
  public PaymentApprovalResult approve(
      PaymentApprovalCommand command
  ) {
    return PaymentApprovalResult.failure(
        "KAKAO_APPROVE_FLOW_REQUIRED",
        "카카오페이는 전용 결제 승인 API를 사용해야 합니다."
    );
  }

  @Override
  public PaymentCancellationResult cancel(
      PaymentCancellationCommand command
  ) {
    String tid = command.providerPaymentKey();

    if (isBlank(tid)) {
      return PaymentCancellationResult.failure(
          "KAKAO_TID_MISSING",
          "취소할 카카오페이 결제 고유번호가 없습니다."
      );
    }

    if (command.amount() < 1) {
      return PaymentCancellationResult.failure(
          "KAKAO_INVALID_CANCEL_AMOUNT",
          "카카오페이 취소 금액은 1원 이상이어야 합니다."
      );
    }

    /*
     * POPQ의 현재 카카오페이 결제 준비 요청은
     * tax_free_amount를 0원으로 전송합니다.
     *
     * 따라서 취소 요청의 비과세 금액도 0원이며,
     * VAT는 카카오페이가 계산하도록 생략합니다.
     */
    CancelCommand cancelCommand =
        new CancelCommand(
            tid,
            command.amount(),
            0L,
            null
        );

    CancelResult cancelResult =
        kakaoPaymentClient.cancel(
            cancelCommand
        );

    if (cancelResult.success()) {
      return validateDirectCancelResult(
          command,
          cancelResult
      );
    }

    /*
     * 취소 API가 통신 오류를 반환했거나,
     * 이미 취소된 결제에 같은 요청이 다시 들어온 경우에는
     * tid로 카카오페이의 실제 주문 상태를 조회합니다.
     */
    return recoverCancelResult(
        command,
        cancelResult
    );
  }

  private PaymentCancellationResult
  validateDirectCancelResult(
      PaymentCancellationCommand command,
      CancelResult result
  ) {
    if (!Objects.equals(
        command.providerPaymentKey(),
        result.tid()
    )) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_TID_MISMATCH",
          "카카오페이 취소 결제번호가 원본 결제와 일치하지 않습니다."
      );
    }

    if (result.approvedCancelAmount()
        != command.amount()) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_AMOUNT_MISMATCH",
          "카카오페이에서 처리된 취소 금액이 요청 금액과 일치하지 않습니다."
      );
    }

    /*
     * 현재 POPQ의 주문 거절·구매자 취소·완료 주문 환불은
     * 모두 승인 금액 전액을 취소합니다.
     *
     * 따라서 부분 취소 상태를 전체 취소 성공으로 처리하면 안 됩니다.
     */
    if (!"CANCEL_PAYMENT".equals(
        result.status()
    )) {
      return PaymentCancellationResult.failure(
          "KAKAO_FULL_CANCEL_NOT_COMPLETED",
          "카카오페이 결제 금액이 전액 취소되지 않았습니다."
      );
    }

    if (isBlank(result.aid())) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_AID_MISSING",
          "카카오페이 취소 요청 고유번호를 확인할 수 없습니다."
      );
    }

    return PaymentCancellationResult.success(
        result.aid()
    );
  }

  private PaymentCancellationResult recoverCancelResult(
      PaymentCancellationCommand command,
      CancelResult originalFailure
  ) {
    LookupResult lookupResult =
        kakaoPaymentOrderClient.lookup(
            command.providerPaymentKey()
        );

    if (!lookupResult.success()) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_STATUS_UNKNOWN",
          createUnknownStatusMessage(
              originalFailure,
              lookupResult
          )
      );
    }

    if (!Objects.equals(
        command.providerPaymentKey(),
        lookupResult.tid()
    )) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_LOOKUP_TID_MISMATCH",
          "카카오페이 주문 조회의 결제번호가 원본 결제와 일치하지 않습니다."
      );
    }

    /*
     * CANCEL_PAYMENT만 POPQ의 전체 취소 성공으로 인정합니다.
     * PART_CANCEL_PAYMENT는 전체 환불 처리로 확정하지 않습니다.
     */
    if (!lookupResult.isFullyCanceled()) {
      return PaymentCancellationResult.failure(
          originalFailure.failureCode(),
          originalFailure.failureMessage()
      );
    }

    if (lookupResult.totalAmount() == null
        || lookupResult.totalAmount()
        != command.amount()) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_LOOKUP_TOTAL_MISMATCH",
          "카카오페이 원결제 금액이 POPQ 취소 요청 금액과 일치하지 않습니다."
      );
    }

    if (lookupResult.canceledAmount() == null
        || lookupResult.canceledAmount()
        != command.amount()) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_LOOKUP_AMOUNT_MISMATCH",
          "카카오페이 누적 취소 금액이 POPQ 취소 요청 금액과 일치하지 않습니다."
      );
    }

    if (lookupResult.cancelAvailableAmount() == null
        || lookupResult.cancelAvailableAmount()
        != 0L) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_REMAINING_AMOUNT",
          "카카오페이에 아직 취소 가능한 결제 잔액이 남아 있습니다."
      );
    }

    if (isBlank(
        lookupResult.latestCancelAid()
    )) {
      return PaymentCancellationResult.failure(
          "KAKAO_CANCEL_AID_MISSING",
          "카카오페이 주문 조회에서 취소 요청 고유번호를 확인할 수 없습니다."
      );
    }

    /*
     * 실제 카카오페이 상태가 전체 취소로 확인되었으므로,
     * 중복 취소 요청이나 응답 유실 상황을 정상 취소로 복구합니다.
     */
    return PaymentCancellationResult.success(
        lookupResult.latestCancelAid()
    );
  }

  private String createUnknownStatusMessage(
      CancelResult originalFailure,
      LookupResult lookupFailure
  ) {
    String cancelMessage =
        defaultMessage(
            originalFailure.failureMessage(),
            "카카오페이 취소 결과를 확인하지 못했습니다."
        );

    String lookupMessage =
        defaultMessage(
            lookupFailure.failureMessage(),
            "카카오페이 주문 상태 조회에도 실패했습니다."
        );

    return cancelMessage
        + " "
        + lookupMessage;
  }

  private String defaultMessage(
      String value,
      String defaultValue
  ) {
    return isBlank(value)
        ? defaultValue
        : value;
  }

  private boolean isBlank(
      String value
  ) {
    return value == null
        || value.isBlank();
  }
}