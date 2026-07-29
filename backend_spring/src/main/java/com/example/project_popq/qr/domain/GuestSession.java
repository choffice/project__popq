package com.example.project_popq.qr.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
@Table(name = "guest_sessions")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class GuestSession extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "guest_session_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "qr_code_id", nullable = false)
    private QrCode qrCode;

    @Column(name = "session_hash", nullable = false, length = 64, unique = true)
    private String sessionHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "last_seen_at", nullable = false)
    private Instant lastSeenAt;

    private GuestSession(
            QrCode qrCode,
            String sessionHash,
            Instant expiresAt,
            Instant now
    ) {
        this.qrCode = qrCode;
        this.sessionHash = sessionHash;
        this.expiresAt = expiresAt;
        this.lastSeenAt = now;
    }

    public static GuestSession create(
            QrCode qrCode,
            String sessionHash,
            Instant expiresAt,
            Instant now
    ) {
        return new GuestSession(qrCode, sessionHash, expiresAt, now);
    }

    public boolean isExpired(Instant now) {
        return now.isAfter(expiresAt);
    }

    public void touch(Instant now) {
        lastSeenAt = now;
    }
}

