package com.example.project_popq.announcement.dto;

import com.example.project_popq.announcement.domain.AnnouncementStatus;
import jakarta.validation.constraints.NotNull;

public record ChangeAnnouncementStatusRequest(
        @NotNull AnnouncementStatus status
) {
}

