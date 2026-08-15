package com.example.project_popq.auth.dto;

import com.example.project_popq.auth.validation.AuthValidationPatterns;
import com.example.project_popq.user.domain.PlatformRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record DevLoginRequest(
        @NotBlank @Email @Size(max = 255)
        @Pattern(regexp = AuthValidationPatterns.EMAIL, message = "올바른 이메일 형식이 아닙니다.")
        String email,
        @NotBlank @Size(min = 2, max = 100) String name,
        @NotNull PlatformRole role
) {
}

