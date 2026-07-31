package com.example.project_popq.payment.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ConfirmPaymentRequest(

    @NotNull
    @Pattern(regexp = "^[A-Za-z0-9_-]{8,100}$")
    String idempotencyKey,

    boolean simulateFailure,

    @Size(max = 200)
    String paymentKey

) {

        /*
         * 기존 테스트 코드 및 기존 Flutter 요청과의 호환성을 위한 생성자입니다.
         *
         * 기존:
         * new ConfirmPaymentRequest("payment-test-01", false)
         *
         * 위 코드도 계속 사용할 수 있으며,
         * paymentKey는 자동으로 null이 됩니다.
         */
        public ConfirmPaymentRequest(
            String idempotencyKey,
            boolean simulateFailure
        ) {
                this(
                    idempotencyKey,
                    simulateFailure,
                    null
                );
        }
}