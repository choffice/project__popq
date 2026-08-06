package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.domain.PaymentProviderType;
import com.example.project_popq.payment.provider.KakaoPaymentClient.CancelCommand;
import com.example.project_popq.payment.provider.KakaoPaymentClient.CancelResult;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class KakaoPaymentProvider implements PaymentProvider {

  private final KakaoPaymentClient kakaoPaymentClient;

  @Override
  public PaymentProviderType providerType() {
    return PaymentProviderType.KAKAO_PAY;
  }

  /**
   * 카카오페이 승인은 ready 단계에서 저장한 tid와
   * 카카오페이 콜백의 pg_token이 모두 필요합니다.
   *
   * 기존 토스용 PaymentApprovalCommand로는 필요한 정보를
   * 안전하게 전달할 수 없으므로 KakaoPaymentService의
   * 전용 승인 흐름을 사용합니다.
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
    if (isBlank(command.providerPaymentKey())) {
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
     * 현재 POPQ의 카카오페이 ready 요청은
     * tax_free_amount를 0으로 전송합니다.
     *
     * 따라서 취소 요청의 비과세 금액도 0이며,
     * VAT는 카카오페이가 자동 계산하도록 생략합니다.
     */
    CancelCommand cancelCommand =
        new CancelCommand(
            command.providerPaymentKey(),
            command.amount(),
            0L,
            null
        );

    CancelResult result =
        kakaoPaymentClient.cancel(
            cancelCommand
        );

    if (!result.success()) {
      return PaymentCancellationResult.failure(
          result.failureCode(),
          result.failureMessage()
      );
    }

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

    if (!isCanceledStatus(result.status())) {
      return PaymentCancellationResult.failure(
          "KAKAO_INVALID_CANCEL_STATUS",
          "카카오페이 취소 상태가 올바르지 않습니다."
      );
    }

    return PaymentCancellationResult.success(
        result.aid()
    );
  }

  private boolean isCanceledStatus(
      String status
  ) {
    return "CANCEL_PAYMENT".equals(status)
        || "PART_CANCEL_PAYMENT".equals(status);
  }

  private boolean isBlank(
      String value
  ) {
    return value == null
        || value.isBlank();
  }
}