package com.example.project_popq.payment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record CreateSellerRefundRequest(
        @Positive long amount,
        @NotBlank @Size(max = 500) String reason
) {
}
