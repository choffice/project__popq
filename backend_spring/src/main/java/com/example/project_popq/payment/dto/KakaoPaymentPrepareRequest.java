package com.example.project_popq.payment.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public record KakaoPaymentPrepareRequest(

        @NotNull
        @Pattern(regexp = "^[A-Za-z0-9_-]{8,100}$")
        String idempotencyKey

) {
}