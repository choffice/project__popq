package com.example.project_popq.product.dto;

import com.example.project_popq.product.domain.CatalogStatus;
import com.example.project_popq.product.domain.ProductCategory;

public record CategoryResponse(
        Long categoryId,
        String name,
        int displayOrder,
        CatalogStatus status
) {
    public static CategoryResponse from(ProductCategory category) {
        return new CategoryResponse(
                category.getId(),
                category.getName(),
                category.getDisplayOrder(),
                category.getStatus()
        );
    }
}

