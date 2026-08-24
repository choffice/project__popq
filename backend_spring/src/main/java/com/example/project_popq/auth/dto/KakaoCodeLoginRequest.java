package com.example.project_popq.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record KakaoCodeLoginRequest(
    @NotBlank
    String code
) {
}
