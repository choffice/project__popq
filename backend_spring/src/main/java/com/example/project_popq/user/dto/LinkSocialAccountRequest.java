package com.example.project_popq.user.dto;

import com.example.project_popq.user.domain.SocialProvider;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record LinkSocialAccountRequest(
        @NotNull SocialProvider provider,
        @NotBlank String providerToken
) {
}
