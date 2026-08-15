package com.example.project_popq.auth.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Duration;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "email_verification_challenges")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class EmailVerificationChallenge extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "email_verification_challenge_id")
    private Long id;

    @Column(name = "email", nullable = false, length = 255)
    private String email;

    @Enumerated(EnumType.STRING)
    @Column(name = "purpose", nullable = false, length = 30)
    private EmailVerificationPurpose purpose;

    @Column(name = "code_hash", nullable = false, length = 255)
    private String codeHash;

    @Column(name = "verification_token_hash", length = 255)
    private String verificationTokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "last_sent_at", nullable = false)
    private Instant lastSentAt;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @Column(name = "consumed_at")
    private Instant consumedAt;

    @Column(name = "failed_attempts", nullable = false)
    private int failedAttempts;

    private EmailVerificationChallenge(
            String email,
            String codeHash,
            Instant now,
            Instant expiresAt
    ) {
        this.email = email;
        this.purpose = EmailVerificationPurpose.SIGNUP;
        this.codeHash = codeHash;
        this.expiresAt = expiresAt;
        this.lastSentAt = now;
    }

    public static EmailVerificationChallenge createForSignup(
            String email,
            String codeHash,
            Instant now,
            Instant expiresAt
    ) {
        return new EmailVerificationChallenge(email, codeHash, now, expiresAt);
    }

    public boolean canResend(Instant now, Duration resendInterval) {
        return !lastSentAt.plus(resendInterval).isAfter(now);
    }

    public void resend(String codeHash, Instant now, Instant expiresAt) {
        this.codeHash = codeHash;
        this.expiresAt = expiresAt;
        this.lastSentAt = now;
        this.verificationTokenHash = null;
        this.verifiedAt = null;
        this.consumedAt = null;
        this.failedAttempts = 0;
    }

    public boolean isExpired(Instant now) {
        return !expiresAt.isAfter(now);
    }

    public boolean hasExceededAttempts(int maxAttempts) {
        return failedAttempts >= maxAttempts;
    }

    public void registerFailedAttempt() {
        failedAttempts++;
    }

    public void verify(String verificationTokenHash, Instant now) {
        this.verificationTokenHash = verificationTokenHash;
        this.verifiedAt = now;
        this.failedAttempts = 0;
    }

    public boolean isVerified() {
        return verifiedAt != null && verificationTokenHash != null;
    }

    public boolean isConsumed() {
        return consumedAt != null;
    }

    public void consume(Instant now) {
        consumedAt = now;
    }
}
