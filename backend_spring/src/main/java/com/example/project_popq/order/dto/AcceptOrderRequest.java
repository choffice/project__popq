package com.example.project_popq.order.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record AcceptOrderRequest(
        @Min(0) @Max(50) int preparationMinutes,
        boolean applyAsStoreDefault,
        @Size(max = 500) String reason
) {
    public String reasonOr(String fallback) {
        return reason == null || reason.isBlank() ? fallback : reason.trim();
    }
}
