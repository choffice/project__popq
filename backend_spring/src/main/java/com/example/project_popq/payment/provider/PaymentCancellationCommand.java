package com.example.project_popq.payment.provider;

public record PaymentCancellationCommand(
        String providerPaymentKey,
        long amount,
        String reason
) {
}

