package com.example.project_popq.payment.provider;

public record PaymentApprovalCommand(

    String orderPublicId,

    long amount,

    String paymentKey,

    boolean simulateFailure

) {
}