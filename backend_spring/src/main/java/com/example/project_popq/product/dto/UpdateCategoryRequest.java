package com.example.project_popq.product.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

public record UpdateCategoryRequest(
        @NotBlank @Size(max = 100) String name,
        @PositiveOrZero int displayOrder
) {
}

