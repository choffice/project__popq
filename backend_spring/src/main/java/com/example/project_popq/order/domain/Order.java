package com.example.project_popq.order.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.qr.domain.GuestSession;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.user.domain.User;
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
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "orders")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Order extends BaseTimeEntity {

    private static final Map<OrderStatus, EnumSet<OrderStatus>> ALLOWED_TRANSITIONS =
            Map.of(
                    OrderStatus.CREATED,
                    EnumSet.of(OrderStatus.PLACED, OrderStatus.EXPIRED),
                    OrderStatus.PLACED,
                    EnumSet.of(
                            OrderStatus.ACCEPTED,
                            OrderStatus.PREPARING,
                            OrderStatus.REJECTED,
                            OrderStatus.CANCELED
                    ),
                    OrderStatus.ACCEPTED,
                    EnumSet.of(OrderStatus.PREPARING),
                    OrderStatus.PREPARING,
                    EnumSet.of(OrderStatus.READY),
                    OrderStatus.READY,
                    EnumSet.of(OrderStatus.COMPLETED)
            );

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "order_id")
    private Long id;

    @Column(name = "order_public_id", nullable = false, length = 40, unique = true)
    private String orderPublicId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "guest_session_id")
    private GuestSession guestSession;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Enumerated(EnumType.STRING)
    @Column(name = "order_type", nullable = false, length = 30)
    private OrderType orderType;

    @Column(name = "request_message", length = 100)
    private String requestMessage;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private OrderStatus status;

    @Column(name = "subtotal_amount", nullable = false)
    private long subtotalAmount;

    @Column(name = "discount_amount", nullable = false)
    private long discountAmount;

    @Column(name = "tax_amount", nullable = false)
    private long taxAmount;

    @Column(name = "service_fee_amount", nullable = false)
    private long serviceFeeAmount;

    @Column(name = "total_amount", nullable = false)
    private long totalAmount;

    @Column(name = "idempotency_key", nullable = false, length = 100, unique = true)
    private String idempotencyKey;

    @Column(name = "request_hash", nullable = false, length = 64)
    private String requestHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "preparation_minutes")
    private Integer preparationMinutes;

    @Column(name = "accepted_at")
    private Instant acceptedAt;

    @Column(name = "estimated_ready_at")
    private Instant estimatedReadyAt;

    @Version
    @Column(name = "version", nullable = false)
    private long version;

    @OneToMany(
            mappedBy = "order",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    @OrderBy("id ASC")
    private List<OrderItem> items = new ArrayList<>();

    @OneToMany(
            mappedBy = "order",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    @OrderBy("changedAt ASC, id ASC")
    private List<OrderStatusHistory> statusHistories = new ArrayList<>();

    private Order(
            String orderPublicId,
            User user,
            GuestSession guestSession,
            Store store,
            OrderType orderType,
            String requestMessage,
            String idempotencyKey,
            String requestHash,
            Instant expiresAt,
            Instant now,
            OrderActorType actorType,
            Long actorId
    ) {
        this.orderPublicId = orderPublicId;
        this.user = user;
        this.guestSession = guestSession;
        this.store = store;
        this.orderType = orderType;
        this.requestMessage = normalizeRequestMessage(requestMessage);
        this.status = OrderStatus.CREATED;
        this.idempotencyKey = idempotencyKey;
        this.requestHash = requestHash;
        this.expiresAt = expiresAt;
        this.statusHistories.add(
                OrderStatusHistory.initial(this, actorType, actorId, now)
        );
    }

    public static Order createGuestOrder(
            String orderPublicId,
            GuestSession guestSession,
            Store store,
            OrderType orderType,
            String idempotencyKey,
            String requestHash,
            Instant expiresAt,
            Instant now
    ) {
        return new Order(
                orderPublicId,
                null,
                guestSession,
                store,
                orderType,
                null,
                idempotencyKey,
                requestHash,
                expiresAt,
                now,
                OrderActorType.GUEST,
                guestSession.getId()
        );
    }

    public static Order createCustomerOrder(
            String orderPublicId,
            User user,
            Store store,
            OrderType orderType,
            String requestMessage,
            String idempotencyKey,
            String requestHash,
            Instant expiresAt,
            Instant now
    ) {
        return new Order(
                orderPublicId,
                user,
                null,
                store,
                orderType,
                requestMessage,
                idempotencyKey,
                requestHash,
                expiresAt,
                now,
                OrderActorType.CUSTOMER,
                user.getId()
        );
    }

    public void addItem(OrderItem item) {
        items.add(item);
        try {
            recalculateAmounts();
        } catch (ArithmeticException exception) {
            items.remove(item);
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST,
                    "주문 금액이 허용 범위를 초과했습니다."
            );
        }
    }

    public OrderTransition transitionTo(
            OrderStatus nextStatus,
            OrderActorType actorType,
            Long actorId,
            String reason,
            Instant now
    ) {
        EnumSet<OrderStatus> allowed = ALLOWED_TRANSITIONS.get(status);
        if (allowed == null || !allowed.contains(nextStatus)) {
            throw new BusinessException(ErrorCode.INVALID_ORDER_STATUS);
        }
        OrderStatus previous = status;
        status = nextStatus;
        statusHistories.add(
                OrderStatusHistory.change(
                        this,
                        previous,
                        nextStatus,
                        actorType,
                        actorId,
                        reason,
                        now
                )
        );
        return new OrderTransition(previous, nextStatus, now);
    }

    public OrderTransition accept(
            int preparationMinutes,
            OrderActorType actorType,
            Long actorId,
            String reason,
            Instant now
    ) {
        OrderTransition transition = transitionTo(
                OrderStatus.PREPARING,
                actorType,
                actorId,
                reason,
                now
        );
        this.preparationMinutes = preparationMinutes;
        this.acceptedAt = now;
        this.estimatedReadyAt = now.plusSeconds(
                Math.multiplyExact((long) preparationMinutes, 60L)
        );
        return transition;
    }

    public boolean isPaymentExpired(Instant now) {
        return status == OrderStatus.CREATED && now.isAfter(expiresAt);
    }

    public boolean belongsToGuestSession(Long guestSessionId) {
        return guestSession != null && guestSession.getId().equals(guestSessionId);
    }

    public boolean belongsToUser(Long userId) {
        return user != null && user.getId().equals(userId);
    }

    private static String normalizeRequestMessage(String requestMessage) {
        if (requestMessage == null) {
            return null;
        }

        String normalized = requestMessage.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private void recalculateAmounts() {
        subtotalAmount = items.stream()
                .mapToLong(OrderItem::getItemTotalPrice)
                .reduce(0L, Math::addExact);
        discountAmount = 0;
        taxAmount = 0;
        serviceFeeAmount = 0;
        totalAmount = Math.addExact(
                Math.subtractExact(subtotalAmount, discountAmount),
                Math.addExact(taxAmount, serviceFeeAmount)
        );
    }
}