package com.example.project_popq.announcement.dto;

import com.example.project_popq.announcement.domain.Announcement;
import com.example.project_popq.announcement.domain.AnnouncementStatus;
import java.time.Instant;

public record AnnouncementResponse(
    Long announcementId,
    Long storeId,
    String title,
    String content,
    String imageUrl,
    AnnouncementStatus status,
    boolean pinned,
    Instant publishedAt,
    Instant createdAt,
    Instant updatedAt
) {
    public static AnnouncementResponse from(
        Announcement announcement
    ) {
        return new AnnouncementResponse(
            announcement.getId(),
            announcement.getStore().getId(),
            announcement.getTitle(),
            announcement.getContent(),
            announcement.getImageUrl(),
            announcement.getStatus(),
            announcement.isPinned(),
            announcement.getPublishedAt(),
            announcement.getCreatedAt(),
            announcement.getUpdatedAt()
        );
    }
}
