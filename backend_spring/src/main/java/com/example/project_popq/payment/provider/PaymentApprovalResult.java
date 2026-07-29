package com.example.project_popq.payment.provider;

public record PaymentApprovalResult(
        boolean success,
        String providerPaymentKey,
        long approvedAmount,
        String failureCode,
        String failureMessage
) {
    public static PaymentApprovalResult success(
            String providerPaymentKey,
            long approvedAmount
    ) {
        return new PaymentApprovalResult(
                true,
                providerPaymentKey,
                approvedAmount,
                null,
                null
        );
    }

    public static PaymentApprovalResult failure(String code, String message) {
        return new PaymentApprovalResult(false, null, 0, code, message);
    }
}

