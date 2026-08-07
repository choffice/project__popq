package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.domain.PaymentProviderType;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class TestPaymentProvider implements PaymentProvider {

    @Override
    public PaymentProviderType providerType() {
        return PaymentProviderType.TEST;
    }

    @Override
    public PaymentApprovalResult approve(
            PaymentApprovalCommand command
    ) {
        if (command.simulateFailure()) {
            return PaymentApprovalResult.failure(
                    "TEST_PAYMENT_FAILED",
                    "테스트 결제 실패가 요청되었습니다."
            );
        }

        return PaymentApprovalResult.success(
                "test-pay-" + UUID.randomUUID(),
                command.amount()
        );
    }

    @Override
    public PaymentCancellationResult cancel(
            PaymentCancellationCommand command
    ) {
        return PaymentCancellationResult.success(
                "test-refund-" + UUID.randomUUID()
        );
    }
}