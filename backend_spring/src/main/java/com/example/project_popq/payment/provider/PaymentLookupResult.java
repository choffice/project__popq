package com.example.project_popq.payment.provider;

import java.time.Instant;

public record PaymentLookupResult(
        boolean success,
        String providerPaymentKey,
        String orderPublicId,
        Long totalAmount,
        Status status,
        Instant approvedAt,
        String failureCode,
        String failureMessage
) {

    public enum Status {
        READY,
        IN_PROGRESS,
        PAID,
        CANCELED,
        PARTIALLY_REFUNDED,
        FAILED,
        EXPIRED,
        UNKNOWN
    }

    public static PaymentLookupResult success(
            String providerPaymentKey,
            String orderPublicId,
            Long totalAmount,
            Status status,
            Instant approvedAt
    ) {
        return new PaymentLookupResult(
                true,
                providerPaymentKey,
                orderPublicId,
                totalAmount,
                status,
                approvedAt,
                null,
                null
        );
    }

    public static PaymentLookupResult failure(
            String code,
            String message
    ) {
        return new PaymentLookupResult(
                false,
                null,
                null,
                null,
                null,
                null,
                code,
                message
        );
    }
}
