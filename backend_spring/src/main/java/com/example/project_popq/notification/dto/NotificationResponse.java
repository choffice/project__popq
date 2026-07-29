package com.example.project_popq.notification.dto;

import com.example.project_popq.notification.domain.NotificationTargetType;
import com.example.project_popq.notification.domain.NotificationType;
import com.example.project_popq.notification.domain.UserNotification;
import java.time.Instant;

public record NotificationResponse(
        Long notificationId,
        NotificationType type,
        NotificationTargetType targetType,
        String targetId,
        String title,
        String message,
        String deepLink,
        boolean read,
        Instant occurredAt
) {
    public static NotificationResponse from(UserNotification notification) {
        return new NotificationResponse(
                notification.getId(),
                notification.getType(),
                notification.getTargetType(),
                notification.getTargetId(),
                notification.getTitle(),
                notification.getMessage(),
                notification.getDeepLink(),
                notification.isRead(),
                notification.getOccurredAt()
        );
    }
}
