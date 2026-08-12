package com.example.project_popq.platformcontent.dto;

import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.ContentStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public final class PlatformAnnouncementRequest {
    private PlatformAnnouncementRequest() {
    }

    public record Save(
            @NotNull AppAudience audience,
            @NotBlank @Size(max = 200) String title,
            @NotBlank @Size(max = 4000) String content,
            Instant publishStartAt,
            Instant publishEndAt
    ) {
    }

    public record ChangeStatus(@NotNull ContentStatus status) {
    }
}
