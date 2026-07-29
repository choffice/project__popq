package com.example.project_popq.order.domain;

import java.time.Instant;

public record OrderTransition(
        OrderStatus previousStatus,
        OrderStatus currentStatus,
        Instant occurredAt
) {
}
