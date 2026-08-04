package com.example.project_popq.auth.dto;

import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.SocialProvider;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record SocialLoginRequest(
    @NotNull
    SocialProvider provider,

    @NotBlank
    String providerToken,

    @NotNull
    PlatformRole role
) {
}