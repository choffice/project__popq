package com.example.project_popq.analytics.dto;

import java.time.LocalDate;
import java.util.List;

public record SalesSummaryResponse(
        LocalDate from,
        LocalDate to,
        long grossSales,
        long netSales,
        long refundedAmount,
        int refundCount,
        int canceledOrderCount,
        long canceledAmount,
        int completedOrderCount,
        long averageOrderAmount,
        long dineInSales,
        long takeoutSales,
        List<DailySalesResponse> dailySales,
        List<TopProductResponse> topProducts
) {
    public record DailySalesResponse(
            LocalDate date,
            long sales,
            int orderCount
    ) {
    }

    public record TopProductResponse(
            String productName,
            int quantity,
            long sales
    ) {
    }
}
