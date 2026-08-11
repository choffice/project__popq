package com.example.project_popq.announcement.dto;

import jakarta.validation.constraints.NotNull;

public record ChangeAnnouncementPinRequest(
        @NotNull Boolean pinned
) {
}
