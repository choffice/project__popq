package com.example.project_popq.payment.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
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
@Table(name = "refunds")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Refund extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "refund_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "payment_id", nullable = false)
    private Payment payment;

    @Column(name = "amount", nullable = false)
    private long amount;

    @Column(name = "reason", nullable = false, length = 500)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(name = "requester_type", nullable = false, length = 30)
    private RefundRequesterType requesterType;

    @Column(name = "requester_id")
    private Long requesterId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private RefundStatus status;

    @Column(name = "provider_refund_key", length = 255, unique = true)
    private String providerRefundKey;

    @Column(name = "requested_at", nullable = false)
    private Instant requestedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "failure_code", length = 100)
    private String failureCode;

    @Column(name = "failure_message", length = 500)
    private String failureMessage;

    private Refund(
            Payment payment,
            long amount,
            String reason,
            RefundRequesterType requesterType,
            Long requesterId,
            Instant requestedAt
    ) {
        this.payment = payment;
        this.amount = amount;
        this.reason = reason;
        this.requesterType = requesterType;
        this.requesterId = requesterId;
        this.requestedAt = requestedAt;
        this.status = RefundStatus.REQUESTED;
    }

    public static Refund requested(
            Payment payment,
            long amount,
            String reason,
            RefundRequesterType requesterType,
            Long requesterId,
            Instant now
    ) {
        return new Refund(
                payment,
                amount,
                reason,
                requesterType,
                requesterId,
                now
        );
    }

    public void markProcessing() {
        status = RefundStatus.PROCESSING;
    }

    public void markSucceeded(String providerRefundKey, Instant completedAt) {
        this.providerRefundKey = providerRefundKey;
        this.completedAt = completedAt;
        this.status = RefundStatus.SUCCEEDED;
    }

    public void markFailed(String failureCode, String failureMessage) {
        this.failureCode = failureCode;
        this.failureMessage = failureMessage;
        this.status = RefundStatus.FAILED;
    }
}

