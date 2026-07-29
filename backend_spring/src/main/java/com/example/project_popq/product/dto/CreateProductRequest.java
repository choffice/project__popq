package com.example.project_popq.product.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

public record CreateProductRequest(
        @NotNull Long categoryId,
        @NotBlank @Size(max = 150) String name,
        @Size(max = 1000) String description,
        @Size(max = 1000) String imageUrl,
        @PositiveOrZero long basePrice
) {
}

