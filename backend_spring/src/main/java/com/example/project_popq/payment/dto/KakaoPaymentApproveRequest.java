package com.example.project_popq.payment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record KakaoPaymentApproveRequest(

    @NotNull
    @Positive
    Long paymentId,

    @NotBlank
    @Size(max = 255)
    String pgToken

) {
}