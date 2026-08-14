package com.example.project_popq.auth.dto;

import com.example.project_popq.auth.validation.AuthValidationPatterns;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record EmailVerificationConfirmRequest(
        @NotBlank @Email @Size(max = 255)
        @Pattern(regexp = AuthValidationPatterns.EMAIL, message = "올바른 이메일 형식이 아닙니다.")
        String email,
        @NotBlank
        @Pattern(regexp = "^\\d{6}$", message = "인증번호는 숫자 6자리여야 합니다.")
        String code
) {
}
