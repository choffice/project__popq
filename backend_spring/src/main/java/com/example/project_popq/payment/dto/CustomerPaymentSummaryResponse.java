package com.example.project_popq.payment.dto;

import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentMethod;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.payment.domain.Refund;
import com.example.project_popq.payment.domain.RefundRequesterType;
import com.example.project_popq.payment.domain.RefundStatus;
import java.time.Instant;
import java.util.List;

public record CustomerPaymentSummaryResponse(
        String orderPublicId,
        PaymentStatus paymentStatus,
        PaymentMethod paymentMethod,
        long approvedAmount,
        long refundedAmount,
        Instant approvedAt,
        Instant canceledAt,
        List<RefundResponse> refunds
) {
    public static CustomerPaymentSummaryResponse from(Payment payment) {
        long approvedAmount = payment.getApprovedAmount() == null
                ? 0
                : payment.getApprovedAmount();

        long refundedAmount = payment.getRefunds().stream()
                .filter(refund -> refund.getStatus() == RefundStatus.SUCCEEDED)
                .mapToLong(Refund::getAmount)
                .sum();

        return new CustomerPaymentSummaryResponse(
                payment.getOrder().getOrderPublicId(),
                payment.getStatus(),
                payment.getPaymentMethod(),
                approvedAmount,
                refundedAmount,
                payment.getApprovedAt(),
                payment.getCanceledAt(),
                payment.getRefunds().stream()
                        .map(RefundResponse::from)
                        .toList()
        );
    }

    public record RefundResponse(
            Long refundId,
            long amount,
            String reason,
            RefundRequesterType requesterType,
            RefundStatus status,
            Instant requestedAt,
            Instant completedAt,
            String failureMessage
    ) {
        private static RefundResponse from(Refund refund) {
            return new RefundResponse(
                    refund.getId(),
                    refund.getAmount(),
                    refund.getReason(),
                    refund.getRequesterType(),
                    refund.getStatus(),
                    refund.getRequestedAt(),
                    refund.getCompletedAt(),
                    refund.getFailureMessage()
            );
        }
    }
}
