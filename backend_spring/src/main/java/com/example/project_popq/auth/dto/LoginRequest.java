package com.example.project_popq.auth.dto;

import com.example.project_popq.user.domain.PlatformRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record LoginRequest(
        @NotBlank @Email @Size(max = 255) String email,
        @NotBlank String password,
        PlatformRole role
) {
}
