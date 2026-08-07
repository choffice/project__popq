package com.example.project_popq.store.dto;

import com.example.project_popq.engagement.dto.ReviewResponse;
import com.example.project_popq.order.dto.OrderResponse;
import java.time.Instant;
import java.util.List;

public record SellerOperationalAlertsResponse(
        List<OrderResponse> orders,
        List<ChatAlertResponse> chats,
        List<ReviewResponse> reviews
) {
    public record ChatAlertResponse(
            Long storeId,
            String storeName,
            String orderPublicId,
            String customerName,
            String lastMessage,
            Instant lastMessageAt
    ) {
    }
}
