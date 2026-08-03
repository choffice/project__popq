package com.example.project_popq.auth.dto;

import com.example.project_popq.user.domain.PlatformRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record SignupRequest(
        @NotBlank @Email @Size(max = 255) String email,
        @NotBlank
        @Size(min = 8, max = 64)
        @Pattern(
                regexp = "^(?=.*[A-Za-z])(?=.*\\d).+$",
                message = "비밀번호는 영문과 숫자를 포함해야 합니다."
        )
        String password,
        @NotBlank @Size(min = 2, max = 100) String name,
        @Size(max = 30) String phone,
        @NotNull PlatformRole role
) {
}
