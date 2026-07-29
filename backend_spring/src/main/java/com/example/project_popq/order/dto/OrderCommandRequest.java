package com.example.project_popq.order.dto;

import jakarta.validation.constraints.Size;

public record OrderCommandRequest(
        @Size(max = 500) String reason
) {
    public String reasonOr(String fallback) {
        return reason == null || reason.isBlank() ? fallback : reason.trim();
    }
}
