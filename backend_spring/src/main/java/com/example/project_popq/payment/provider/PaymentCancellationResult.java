package com.example.project_popq.payment.provider;

public record PaymentCancellationResult(
        boolean success,
        String providerRefundKey,
        String failureCode,
        String failureMessage
) {
    public static PaymentCancellationResult success(String providerRefundKey) {
        return new PaymentCancellationResult(
                true,
                providerRefundKey,
                null,
                null
        );
    }

    public static PaymentCancellationResult failure(String code, String message) {
        return new PaymentCancellationResult(false, null, code, message);
    }
}

