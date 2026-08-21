package com.example.project_popq.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record NaverCodeLoginRequest(
    @NotBlank String code,
    @NotBlank String state
) {
}
