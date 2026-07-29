package com.example.project_popq.admin.dto;

public record AdminOverviewResponse(
        long totalUsers,
        long activeUsers,
        long sellerProfiles,
        long pendingSellers,
        long totalStores,
        long activeStores,
        long suspendedStores
) {
}
