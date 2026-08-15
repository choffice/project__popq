CREATE TABLE email_verification_challenges (
    email_verification_challenge_id BIGINT NOT NULL AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL,
    purpose VARCHAR(30) NOT NULL,
    code_hash VARCHAR(255) NOT NULL,
    verification_token_hash VARCHAR(255) NULL,
    expires_at DATETIME(6) NOT NULL,
    last_sent_at DATETIME(6) NOT NULL,
    verified_at DATETIME(6) NULL,
    consumed_at DATETIME(6) NULL,
    failed_attempts INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (email_verification_challenge_id),
    UNIQUE KEY uk_email_verification_email_purpose (email, purpose),
    KEY idx_email_verification_expires_at (expires_at)
);
