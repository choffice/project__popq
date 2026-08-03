package com.example.project_popq.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PasswordResetVerifyRequest(
        @NotBlank @Email @Size(max = 255) String email,
        @NotBlank
        @Pattern(
                regexp = "^01[0-9]-?\\d{3,4}-?\\d{4}$",
                message = "전화번호 형식이 올바르지 않습니다."
        )
        String phone
) {
}
