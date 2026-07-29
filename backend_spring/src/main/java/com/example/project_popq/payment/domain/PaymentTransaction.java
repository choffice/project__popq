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
@Table(name = "payment_transactions")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PaymentTransaction extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "payment_transaction_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "payment_id", nullable = false)
    private Payment payment;

    @Enumerated(EnumType.STRING)
    @Column(name = "transaction_type", nullable = false, length = 30)
    private PaymentTransactionType transactionType;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private PaymentTransactionStatus status;

    @Column(name = "request_payload", columnDefinition = "TEXT")
    private String requestPayload;

    @Column(name = "response_payload", columnDefinition = "TEXT")
    private String responsePayload;

    @Column(name = "failure_code", length = 100)
    private String failureCode;

    @Column(name = "failure_message", length = 500)
    private String failureMessage;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    private PaymentTransaction(
            Payment payment,
            PaymentTransactionType transactionType,
            PaymentTransactionStatus status,
            String requestPayload,
            String responsePayload,
            String failureCode,
            String failureMessage,
            Instant occurredAt
    ) {
        this.payment = payment;
        this.transactionType = transactionType;
        this.status = status;
        this.requestPayload = requestPayload;
        this.responsePayload = responsePayload;
        this.failureCode = failureCode;
        this.failureMessage = failureMessage;
        this.occurredAt = occurredAt;
    }

    public static PaymentTransaction succeeded(
            Payment payment,
            PaymentTransactionType type,
            String requestPayload,
            String responsePayload,
            Instant now
    ) {
        return new PaymentTransaction(
                payment,
                type,
                PaymentTransactionStatus.SUCCEEDED,
                requestPayload,
                responsePayload,
                null,
                null,
                now
        );
    }

    public static PaymentTransaction failed(
            Payment payment,
            PaymentTransactionType type,
            String requestPayload,
            String responsePayload,
            String failureCode,
            String failureMessage,
            Instant now
    ) {
        return new PaymentTransaction(
                payment,
                type,
                PaymentTransactionStatus.FAILED,
                requestPayload,
                responsePayload,
                failureCode,
                failureMessage,
                now
        );
    }
}

