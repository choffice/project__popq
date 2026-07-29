package com.example.project_popq.product.dto;

import com.example.project_popq.product.domain.CatalogStatus;
import com.example.project_popq.product.domain.Product;
import java.time.Instant;

public record ProductSummaryResponse(
        Long productId,
        Long categoryId,
        String categoryName,
        String name,
        String description,
        String imageUrl,
        long basePrice,
        CatalogStatus status,
        boolean soldOut,
        boolean availableForQr,
        boolean availableForCustomerApp,
        Instant salesStartAt,
        Instant salesEndAt,
        boolean qrWebEnabled,
        boolean customerAppEnabled
) {
    public static ProductSummaryResponse from(Product product, Instant now) {
        return new ProductSummaryResponse(
                product.getId(),
                product.getCategory().getId(),
                product.getCategory().getName(),
                product.getName(),
                product.getDescription(),
                product.getImageUrl(),
                product.getBasePrice(),
                product.getStatus(),
                product.getAvailability().isSoldOut(),
                product.getAvailability().isAvailableForQr(now),
                product.getAvailability().isAvailableForCustomerApp(now),
                product.getAvailability().getSalesStartAt(),
                product.getAvailability().getSalesEndAt(),
                product.getAvailability().isQrWebEnabled(),
                product.getAvailability().isCustomerAppEnabled()
        );
    }
}
