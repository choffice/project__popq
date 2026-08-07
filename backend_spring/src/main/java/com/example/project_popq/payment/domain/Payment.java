package com.example.project_popq.payment.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.order.domain.Order;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "payments")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Payment extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "payment_id")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false, unique = true)
    private Order order;

    @Enumerated(EnumType.STRING)
    @Column(name = "provider", nullable = false, length = 30)
    private PaymentProviderType provider;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_method", nullable = false, length = 30)
    private PaymentMethod paymentMethod;

    @Column(name = "requested_amount", nullable = false)
    private long requestedAmount;

    @Column(name = "approved_amount")
    private Long approvedAmount;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private PaymentStatus status;

    @Column(name = "provider_payment_key", length = 255)
    private String providerPaymentKey;

    @Column(name = "idempotency_key", nullable = false, length = 100, unique = true)
    private String idempotencyKey;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "canceled_at")
    private Instant canceledAt;

    @Column(name = "failure_code", length = 100)
    private String failureCode;

    @Column(name = "failure_message", length = 500)
    private String failureMessage;

    @OneToMany(
            mappedBy = "payment",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    @OrderBy("occurredAt ASC, id ASC")
    private List<PaymentTransaction> transactions = new ArrayList<>();

    @OneToMany(
            mappedBy = "payment",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    @OrderBy("requestedAt ASC, id ASC")
    private List<Refund> refunds = new ArrayList<>();

    private Payment(
            Order order,
            PaymentProviderType provider,
            PaymentMethod paymentMethod,
            long requestedAmount,
            String idempotencyKey
    ) {
        this.order = order;
        this.provider = provider;
        this.paymentMethod = paymentMethod;
        this.requestedAmount = requestedAmount;
        this.idempotencyKey = idempotencyKey;
        this.status = PaymentStatus.READY;
    }

    public static Payment ready(
            Order order,
            PaymentProviderType provider,
            PaymentMethod paymentMethod,
            long requestedAmount,
            String idempotencyKey
    ) {
        return new Payment(
                order,
                provider,
                paymentMethod,
                requestedAmount,
                idempotencyKey
        );
    }

    public void markInProgress(String providerPaymentKey) {
        this.providerPaymentKey = providerPaymentKey;
        status = PaymentStatus.IN_PROGRESS;
    }

    public void markPaid(
            long approvedAmount,
            String providerPaymentKey,
            Instant approvedAt
    ) {
        this.approvedAmount = approvedAmount;
        this.providerPaymentKey = providerPaymentKey;
        this.approvedAt = approvedAt;
        this.failureCode = null;
        this.failureMessage = null;
        this.status = PaymentStatus.PAID;
    }

    public void markFailed(String failureCode, String failureMessage) {
        this.failureCode = failureCode;
        this.failureMessage = failureMessage;
        this.status = PaymentStatus.FAILED;
    }

    public void markCanceled(Instant canceledAt) {
        this.canceledAt = canceledAt;
        this.status = PaymentStatus.CANCELED;
    }

    public void markRefunded(Instant refundedAt) {
        this.canceledAt = refundedAt;
        this.status = PaymentStatus.REFUNDED;
    }

    public void markPartiallyRefunded() {
        this.canceledAt = null;
        this.status = PaymentStatus.PARTIALLY_REFUNDED;
    }

    public void addTransaction(PaymentTransaction transaction) {
        transactions.add(transaction);
    }

    public void addRefund(Refund refund) {
        refunds.add(refund);
    }
}
