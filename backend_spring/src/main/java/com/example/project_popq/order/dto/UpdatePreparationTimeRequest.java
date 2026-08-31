package com.example.project_popq.order.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record UpdatePreparationTimeRequest(
        @Min(0)
        @Max(50)
        int preparationMinutes,

        boolean applyAsStoreDefault
) {
}