package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.domain.PaymentProviderType;

public interface PaymentProvider {

    PaymentProviderType providerType();

    PaymentApprovalResult approve(PaymentApprovalCommand command);

    PaymentCancellationResult cancel(PaymentCancellationCommand command);
}