package com.example.project_popq.realtime.event;

import com.example.project_popq.order.domain.OrderStatus;
import java.time.Instant;

public record OrderRealtimeEvent(
        String eventId,
        OrderRealtimeEventType eventType,
        String orderPublicId,
        Long storeId,
        Long guestSessionId,
        Long userId,
        OrderStatus previousStatus,
        OrderStatus currentStatus,
        Instant occurredAt,
        long version
) {
}
