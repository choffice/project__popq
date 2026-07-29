package com.example.project_popq.payment.provider;

public interface PaymentProvider {

    PaymentApprovalResult approve(PaymentApprovalCommand command);

    PaymentCancellationResult cancel(PaymentCancellationCommand command);
}

