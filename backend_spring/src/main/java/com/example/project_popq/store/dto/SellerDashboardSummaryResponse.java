package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.BusinessStatus;

public record SellerDashboardSummaryResponse(
        Long storeId,
        String storeName,
        BusinessStatus businessStatus,
        long waitingOrderCount,
        long activeOrderCount,
        long readyOrderCount,
        long unansweredReviewCount,
        long unreadChatCount
) {
}
