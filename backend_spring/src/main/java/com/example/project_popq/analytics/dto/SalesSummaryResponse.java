package com.example.project_popq.analytics.dto;

import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderType;
import java.time.Instant;
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
        List<TopProductResponse> topProducts,
        List<OrderSalesDetailResponse> orderHistory,
        List<RefundDetailResponse> refundHistory,
        List<CancellationDetailResponse> cancellationHistory
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

    public record OrderSalesDetailResponse(
            String orderPublicId,
            OrderType orderType,
            long approvedAmount,
            long refundedAmount,
            long netSales,
            Instant completedAt,
            int itemCount,
            String itemSummary
    ) {
    }

    public record RefundDetailResponse(
            Long refundId,
            String orderPublicId,
            long amount,
            String reason,
            String requesterType,
            Instant completedAt
    ) {
    }

    public record CancellationDetailResponse(
            String orderPublicId,
            OrderStatus status,
            long amount,
            String reason,
            Instant canceledAt
    ) {
    }
}
