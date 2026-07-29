package com.example.project_popq.realtime.event;

import com.example.project_popq.order.domain.OrderStatus;

public enum OrderRealtimeEventType {
    ORDER_PLACED,
    ORDER_ACCEPTED,
    ORDER_PREPARING,
    ORDER_READY,
    ORDER_COMPLETED,
    ORDER_CANCELED,
    ORDER_REJECTED,
    ORDER_EXPIRED;

    public static OrderRealtimeEventType from(OrderStatus status) {
        return valueOf("ORDER_" + status.name());
    }
}
