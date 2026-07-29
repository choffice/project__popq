package com.example.project_popq.notification.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.user.domain.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "notifications")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserNotification extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "notification_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "event_id", nullable = false, length = 40, unique = true)
    private String eventId;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 30)
    private NotificationType type;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_type", nullable = false, length = 30)
    private NotificationTargetType targetType;

    @Column(name = "target_id", nullable = false, length = 100)
    private String targetId;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "message", nullable = false, length = 500)
    private String message;

    @Column(name = "deep_link", nullable = false, length = 300)
    private String deepLink;

    @Column(name = "is_read", nullable = false)
    private boolean read;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    private UserNotification(
            User user,
            String eventId,
            NotificationType type,
            NotificationTargetType targetType,
            String targetId,
            String title,
            String message,
            String deepLink,
            Instant occurredAt
    ) {
        this.user = user;
        this.eventId = eventId;
        this.type = type;
        this.targetType = targetType;
        this.targetId = targetId;
        this.title = title;
        this.message = message;
        this.deepLink = deepLink;
        this.occurredAt = occurredAt;
        this.read = false;
    }

    public static UserNotification orderStatus(
            User user,
            String eventId,
            String orderPublicId,
            String title,
            String message,
            Instant occurredAt
    ) {
        return new UserNotification(
                user,
                eventId,
                NotificationType.ORDER_STATUS,
                NotificationTargetType.ORDER,
                orderPublicId,
                title,
                message,
                "/orders/" + orderPublicId,
                occurredAt
        );
    }

    public void markRead() {
        read = true;
    }
}
