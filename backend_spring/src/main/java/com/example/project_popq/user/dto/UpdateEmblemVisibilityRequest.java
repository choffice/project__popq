package com.example.project_popq.user.dto;

import jakarta.validation.constraints.NotNull;

public record UpdateEmblemVisibilityRequest(
        @NotNull Boolean emblemVisible
) {
}
