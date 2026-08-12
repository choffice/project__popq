package com.example.project_popq.platformcontent.dto;

import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.ContentStatus;
import com.example.project_popq.platformcontent.domain.PlatformAnnouncement;
import java.time.Instant;

public record PlatformAnnouncementResponse(
        Long platformAnnouncementId,
        AppAudience audience,
        String title,
        String content,
        ContentStatus status,
        Instant publishStartAt,
        Instant publishEndAt,
        String authorName,
        Instant createdAt,
        Instant updatedAt
) {
    public static PlatformAnnouncementResponse from(PlatformAnnouncement announcement) {
        return new PlatformAnnouncementResponse(
                announcement.getId(),
                announcement.getAudience(),
                announcement.getTitle(),
                announcement.getContent(),
                announcement.getStatus(),
                announcement.getPublishStartAt(),
                announcement.getPublishEndAt(),
                announcement.getAuthor().getName(),
                announcement.getCreatedAt(),
                announcement.getUpdatedAt()
        );
    }
}
