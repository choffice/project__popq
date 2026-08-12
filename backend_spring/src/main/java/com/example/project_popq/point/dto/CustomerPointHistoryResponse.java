package com.example.project_popq.point.dto;

import com.example.project_popq.point.domain.CustomerPointTransaction;
import com.example.project_popq.point.domain.CustomerPointTransactionType;
import java.time.Instant;

public record CustomerPointHistoryResponse(
        Long transactionId,
        CustomerPointTransactionType type,
        long points,
        String orderPublicId,
        String storeName,
        long paymentAmount,
        Instant occurredAt
) {
    public static CustomerPointHistoryResponse from(
            CustomerPointTransaction transaction
    ) {
        return new CustomerPointHistoryResponse(
                transaction.getId(),
                transaction.getTransactionType(),
                transaction.getPointAmount(),
                transaction.getOrderPublicId(),
                transaction.getStoreName(),
                transaction.getPaymentAmount(),
                transaction.getOccurredAt()
        );
    }
}
