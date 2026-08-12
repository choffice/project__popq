package com.example.project_popq.point.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.user.domain.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "customer_point_transactions")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CustomerPointTransaction extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "customer_point_transaction_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "transaction_type", nullable = false, length = 30)
    private CustomerPointTransactionType transactionType;

    @Column(name = "point_amount", nullable = false)
    private long pointAmount;

    @Column(name = "source_key", nullable = false, length = 100, unique = true)
    private String sourceKey;

    @Column(name = "order_public_id", nullable = false, length = 40)
    private String orderPublicId;

    @Column(name = "store_name", nullable = false, length = 150)
    private String storeName;

    @Column(name = "payment_amount", nullable = false)
    private long paymentAmount;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    private CustomerPointTransaction(
            User user,
            CustomerPointTransactionType transactionType,
            long pointAmount,
            String sourceKey,
            String orderPublicId,
            String storeName,
            long paymentAmount,
            Instant occurredAt
    ) {
        this.user = user;
        this.transactionType = transactionType;
        this.pointAmount = pointAmount;
        this.sourceKey = sourceKey;
        this.orderPublicId = orderPublicId;
        this.storeName = storeName;
        this.paymentAmount = paymentAmount;
        this.occurredAt = occurredAt;
    }

    public static CustomerPointTransaction paymentReward(
            User user,
            Long paymentId,
            String orderPublicId,
            String storeName,
            long paymentAmount,
            long points,
            Instant occurredAt
    ) {
        return new CustomerPointTransaction(
                user,
                CustomerPointTransactionType.PAYMENT_REWARD,
                points,
                "PAYMENT:" + paymentId,
                orderPublicId,
                storeName,
                paymentAmount,
                occurredAt
        );
    }

    public static CustomerPointTransaction refundReclaim(
            User user,
            String sourceKey,
            String orderPublicId,
            String storeName,
            long refundAmount,
            long points,
            Instant occurredAt
    ) {
        return new CustomerPointTransaction(
                user,
                CustomerPointTransactionType.REFUND_RECLAIM,
                -points,
                sourceKey,
                orderPublicId,
                storeName,
                refundAmount,
                occurredAt
        );
    }

    public static CustomerPointTransaction raffleTicketPurchase(
            User user,
            Long entryId,
            String roundMonth,
            long pointCost,
            Instant occurredAt
    ) {
        return new CustomerPointTransaction(
                user,
                CustomerPointTransactionType.RAFFLE_TICKET_PURCHASE,
                -pointCost,
                "RAFFLE_TICKET:" + entryId,
                "RAFFLE:" + roundMonth,
                "월간 응모 이벤트",
                pointCost,
                occurredAt
        );
    }
}
