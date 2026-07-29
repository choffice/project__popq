package com.example.project_popq.order.dto;

import com.example.project_popq.order.domain.Order;

public record OrderSyncResponse(
        boolean refreshRequired,
        long serverVersion,
        OrderResponse order
) {
    public static OrderSyncResponse from(Order order, long knownVersion) {
        boolean refreshRequired = knownVersion != order.getVersion();
        return new OrderSyncResponse(
                refreshRequired,
                order.getVersion(),
                refreshRequired ? OrderResponse.from(order) : null
        );
    }
}
