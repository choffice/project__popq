package com.example.project_popq.user.dto;

import jakarta.validation.constraints.NotNull;

public record UpdateNotificationPreferenceRequest(
        @NotNull Boolean pushNotificationEnabled,
        @NotNull Boolean marketingOptIn
) {
}
