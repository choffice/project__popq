package com.example.project_popq.order.domain;

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
@Table(name = "order_status_histories")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderStatusHistory extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "order_status_history_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Enumerated(EnumType.STRING)
    @Column(name = "previous_status", length = 30)
    private OrderStatus previousStatus;

    @Enumerated(EnumType.STRING)
    @Column(name = "current_status", nullable = false, length = 30)
    private OrderStatus currentStatus;

    @Enumerated(EnumType.STRING)
    @Column(name = "actor_type", nullable = false, length = 30)
    private OrderActorType actorType;

    @Column(name = "actor_id")
    private Long actorId;

    @Column(name = "reason", length = 500)
    private String reason;

    @Column(name = "changed_at", nullable = false)
    private Instant changedAt;

    private OrderStatusHistory(
            Order order,
            OrderStatus previousStatus,
            OrderStatus currentStatus,
            OrderActorType actorType,
            Long actorId,
            String reason,
            Instant changedAt
    ) {
        this.order = order;
        this.previousStatus = previousStatus;
        this.currentStatus = currentStatus;
        this.actorType = actorType;
        this.actorId = actorId;
        this.reason = reason;
        this.changedAt = changedAt;
    }

    public static OrderStatusHistory initial(
            Order order,
            OrderActorType actorType,
            Long actorId,
            Instant now
    ) {
        return new OrderStatusHistory(
                order,
                null,
                OrderStatus.CREATED,
                actorType,
                actorId,
                null,
                now
        );
    }

    public static OrderStatusHistory change(
            Order order,
            OrderStatus previousStatus,
            OrderStatus currentStatus,
            OrderActorType actorType,
            Long actorId,
            String reason,
            Instant now
    ) {
        return new OrderStatusHistory(
                order,
                previousStatus,
                currentStatus,
                actorType,
                actorId,
                reason,
                now
        );
    }
}

