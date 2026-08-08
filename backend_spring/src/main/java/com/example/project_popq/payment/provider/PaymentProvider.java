package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.domain.PaymentProviderType;

public interface PaymentProvider {

    PaymentProviderType providerType();

    PaymentApprovalResult approve(PaymentApprovalCommand command);

    PaymentCancellationResult cancel(PaymentCancellationCommand command);

    default PaymentLookupResult lookup(
            String providerPaymentKey
    ) {
        return PaymentLookupResult.failure(
                "PAYMENT_LOOKUP_NOT_SUPPORTED",
                "해당 결제 제공자는 결제 상태 조회를 지원하지 않습니다."
        );
    }
}
