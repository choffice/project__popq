package com.example.project_popq.announcement.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.store.domain.Store;
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
@Table(name = "announcements")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Announcement extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "announcement_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "content", nullable = false, length = 2000)
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private AnnouncementStatus status;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Column(name = "pinned", nullable = false)
    private boolean pinned;

    @Column(name = "image_url", length = 1000)
    private String imageUrl;

    private Announcement(
        Store store,
        String title,
        String content,
        String imageUrl
    ) {
        this.store = store;
        this.title = title;
        this.content = content;
        this.imageUrl = imageUrl;
        this.status = AnnouncementStatus.DRAFT;
    }

    public static Announcement create(
        Store store,
        String title,
        String content,
        String imageUrl
    ) {
        return new Announcement(
            store,
            title,
            content,
            imageUrl
        );
    }

    public void update(
        String title,
        String content,
        String imageUrl
    ) {
        this.title = title;
        this.content = content;
        this.imageUrl = imageUrl;
    }

    public void changeStatus(AnnouncementStatus status, Instant now) {
        this.status = status;
        if (status == AnnouncementStatus.PUBLISHED) {
            this.publishedAt = now;
        } else {
            this.pinned = false;
        }
    }

    public void pin() {
        if (status != AnnouncementStatus.PUBLISHED) {
            throw new IllegalStateException("only published announcements can be pinned");
        }
        this.pinned = true;
    }

    public void unpin() {
        this.pinned = false;
    }
}
