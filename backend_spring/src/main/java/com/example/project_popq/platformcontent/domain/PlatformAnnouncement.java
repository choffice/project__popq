package com.example.project_popq.platformcontent.domain;

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
@Table(name = "platform_announcements")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PlatformAnnouncement extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "platform_announcement_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "audience", nullable = false, length = 30)
    private AppAudience audience;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "content", nullable = false, length = 4000)
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private ContentStatus status;

    @Column(name = "publish_start_at")
    private Instant publishStartAt;

    @Column(name = "publish_end_at")
    private Instant publishEndAt;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "author_user_id", nullable = false)
    private User author;

    private PlatformAnnouncement(
            User author,
            AppAudience audience,
            String title,
            String content,
            Instant publishStartAt,
            Instant publishEndAt
    ) {
        this.author = author;
        this.status = ContentStatus.DRAFT;
        update(audience, title, content, publishStartAt, publishEndAt);
    }

    public static PlatformAnnouncement create(
            User author,
            AppAudience audience,
            String title,
            String content,
            Instant publishStartAt,
            Instant publishEndAt
    ) {
        return new PlatformAnnouncement(
                author,
                audience,
                title,
                content,
                publishStartAt,
                publishEndAt
        );
    }

    public void update(
            AppAudience audience,
            String title,
            String content,
            Instant publishStartAt,
            Instant publishEndAt
    ) {
        this.audience = audience;
        this.title = title.trim();
        this.content = content.trim();
        this.publishStartAt = publishStartAt;
        this.publishEndAt = publishEndAt;
    }

    public void changeStatus(ContentStatus status) {
        this.status = status;
    }
}
