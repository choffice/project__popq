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
    @JoinColumn(
        name = "order_id",
        nullable = false,
        unique = true
    )
    private Order order;

    @Enumerated(EnumType.STRING)
    @Column(
        name = "provider",
        nullable = false,
        length = 30
    )
    private PaymentProviderType provider;

    @Enumerated(EnumType.STRING)
    @Column(
        name = "payment_method",
        nullable = false,
        length = 30
    )
    private PaymentMethod paymentMethod;

    @Column(
        name = "requested_amount",
        nullable = false
    )
    private long requestedAmount;

    @Column(name = "approved_amount")
    private Long approvedAmount;

    @Enumerated(EnumType.STRING)
    @Column(
        name = "status",
        nullable = false,
        length = 30
    )
    private PaymentStatus status;

    @Column(
        name = "provider_payment_key",
        length = 255
    )
    private String providerPaymentKey;

    @Column(
        name = "provider_redirect_url",
        length = 1000
    )
    private String providerRedirectUrl;

    @Column(name = "provider_expires_at")
    private Instant providerExpiresAt;

    @Column(
        name = "idempotency_key",
        nullable = false,
        length = 100,
        unique = true
    )
    private String idempotencyKey;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "canceled_at")
    private Instant canceledAt;

    @Column(
        name = "failure_code",
        length = 100
    )
    private String failureCode;

    @Column(
        name = "failure_message",
        length = 500
    )
    private String failureMessage;

    @OneToMany(
        mappedBy = "payment",
        cascade = CascadeType.ALL,
        orphanRemoval = true
    )
    @OrderBy("occurredAt ASC, id ASC")
    private List<PaymentTransaction> transactions =
        new ArrayList<>();

    @OneToMany(
        mappedBy = "payment",
        cascade = CascadeType.ALL,
        orphanRemoval = true
    )
    @OrderBy("requestedAt ASC, id ASC")
    private List<Refund> refunds =
        new ArrayList<>();

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

    /**
     * 토스페이먼츠처럼 별도의 리다이렉트 URL 저장이 필요하지 않은
     * 결제를 진행 중 상태로 변경합니다.
     */
    public void markInProgress(
        String providerPaymentKey
    ) {
        this.providerPaymentKey = providerPaymentKey;

        this.providerRedirectUrl = null;
        this.providerExpiresAt = null;

        this.failureCode = null;
        this.failureMessage = null;

        this.status = PaymentStatus.IN_PROGRESS;
    }

    /**
     * 리다이렉트 방식 결제의 준비 결과를 저장합니다.
     *
     * 현재 토스 통합결제에서는 사용하지 않지만,
     * 이미 적용된 DB 컬럼과의 호환성을 위해 유지합니다.
     */
    public void markPrepared(
        String providerPaymentKey,
        String providerRedirectUrl,
        Instant providerExpiresAt
    ) {
        this.providerPaymentKey = providerPaymentKey;
        this.providerRedirectUrl = providerRedirectUrl;
        this.providerExpiresAt = providerExpiresAt;

        this.failureCode = null;
        this.failureMessage = null;

        this.status = PaymentStatus.IN_PROGRESS;
    }

    /**
     * 기존에 준비된 리다이렉트 결제 정보를 재사용할 수 있는지 확인합니다.
     */
    public boolean hasReusablePreparation(
        Instant now
    ) {
        return status == PaymentStatus.IN_PROGRESS
            && hasText(providerPaymentKey)
            && hasText(providerRedirectUrl)
            && providerExpiresAt != null
            && now.isBefore(providerExpiresAt);
    }

    /**
     * 결제 준비 실패 시 저장된 준비 정보를 제거합니다.
     */
    public void markPreparationFailed(
        String failureCode,
        String failureMessage
    ) {
        this.providerPaymentKey = null;
        this.providerRedirectUrl = null;
        this.providerExpiresAt = null;

        markFailed(
            failureCode,
            failureMessage
        );
    }

    public void markPaid(
        long approvedAmount,
        String providerPaymentKey,
        Instant approvedAt
    ) {
        this.approvedAmount = approvedAmount;
        this.providerPaymentKey = providerPaymentKey;

        this.providerRedirectUrl = null;
        this.providerExpiresAt = null;

        this.approvedAt = approvedAt;

        this.failureCode = null;
        this.failureMessage = null;

        this.status = PaymentStatus.PAID;
    }

    public void markUncertain(
        String failureCode,
        String failureMessage
    ) {
        this.failureCode = failureCode;
        this.failureMessage = failureMessage;
        this.status = PaymentStatus.IN_PROGRESS;
    }

    public void markFailed(
        String failureCode,
        String failureMessage
    ) {
        this.failureCode = failureCode;
        this.failureMessage = failureMessage;
        this.status = PaymentStatus.FAILED;
    }

    public void restartAfterFailure(
        String newIdempotencyKey,
        String newProviderPaymentKey
    ) {
        if (status != PaymentStatus.FAILED) {
            throw new IllegalStateException(
                "실패한 결제만 새 승인 요청으로 재시도할 수 있습니다."
            );
        }

        this.idempotencyKey = newIdempotencyKey;
        this.providerPaymentKey = newProviderPaymentKey;

        this.providerRedirectUrl = null;
        this.providerExpiresAt = null;

        this.approvedAmount = null;
        this.approvedAt = null;
        this.canceledAt = null;

        this.failureCode = null;
        this.failureMessage = null;

        this.status = PaymentStatus.IN_PROGRESS;
    }

    public void markCanceled(
        Instant canceledAt
    ) {
        this.providerRedirectUrl = null;
        this.providerExpiresAt = null;

        this.canceledAt = canceledAt;
        this.status = PaymentStatus.CANCELED;
    }

    public void markRefunded(
        Instant refundedAt
    ) {
        this.providerRedirectUrl = null;
        this.providerExpiresAt = null;

        this.canceledAt = refundedAt;
        this.status = PaymentStatus.REFUNDED;
    }

    public void markPartiallyRefunded() {
        this.canceledAt = null;
        this.status = PaymentStatus.PARTIALLY_REFUNDED;
    }

    public void addTransaction(
        PaymentTransaction transaction
    ) {
        transactions.add(transaction);
    }

    public void addRefund(
        Refund refund
    ) {
        refunds.add(refund);
    }

    private boolean hasText(
        String value
    ) {
        return value != null
            && !value.isBlank();
    }
}