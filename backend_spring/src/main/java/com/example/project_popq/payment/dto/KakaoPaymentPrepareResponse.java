package com.example.project_popq.payment.dto;

import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentProviderType;
import com.example.project_popq.payment.domain.PaymentStatus;
import java.time.Instant;

public record KakaoPaymentPrepareResponse(

        Long paymentId,

        String orderPublicId,

        PaymentProviderType provider,

        PaymentStatus status,

        long amount,

        String redirectUrl,

        Instant expiresAt,

        boolean reused

) {

    public static KakaoPaymentPrepareResponse from(
            Payment payment,
            boolean reused
    ) {
        return new KakaoPaymentPrepareResponse(
                payment.getId(),
                payment
                        .getOrder()
                        .getOrderPublicId(),
                payment.getProvider(),
                payment.getStatus(),
                payment.getRequestedAmount(),
                payment.getProviderRedirectUrl(),
                payment.getProviderExpiresAt(),
                reused
        );
    }
}