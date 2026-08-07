package com.example.project_popq.order.dto;

import java.time.Instant;

public record VisitedStoreResponse(
        Long storeId,
        String storeName,
        String storeCategory,
        String storeImageUrl,
        Instant lastVisitedAt
) {
}
