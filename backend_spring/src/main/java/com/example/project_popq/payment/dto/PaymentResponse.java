package com.example.project_popq.payment.dto;

import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentMethod;
import com.example.project_popq.payment.domain.PaymentProviderType;
import com.example.project_popq.payment.domain.PaymentStatus;
import java.time.Instant;

public record PaymentResponse(
        Long paymentId,
        String orderPublicId,
        PaymentProviderType provider,
        PaymentMethod paymentMethod,
        PaymentStatus status,
        long requestedAmount,
        Long approvedAmount,
        String providerPaymentKey,
        Instant approvedAt,
        Instant canceledAt,
        String failureCode,
        String failureMessage,
        OrderStatus orderStatus
) {
    public static PaymentResponse from(Payment payment) {
        return new PaymentResponse(
                payment.getId(),
                payment.getOrder().getOrderPublicId(),
                payment.getProvider(),
                payment.getPaymentMethod(),
                payment.getStatus(),
                payment.getRequestedAmount(),
                payment.getApprovedAmount(),
                payment.getProviderPaymentKey(),
                payment.getApprovedAt(),
                payment.getCanceledAt(),
                payment.getFailureCode(),
                payment.getFailureMessage(),
                payment.getOrder().getStatus()
        );
    }
}
