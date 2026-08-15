package com.example.project_popq.product.dto;

import java.util.List;

public record StoreOptionTemplateUsageResponse(
        Long templateId,
        int totalCount,
        List<ProductUsage> products
) {
    public record ProductUsage(Long productId, String productName) {
    }
}
