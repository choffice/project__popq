ALTER TABLE payments
    ADD COLUMN provider_redirect_url VARCHAR(1000) NULL
        AFTER provider_payment_key,
    ADD COLUMN provider_expires_at TIMESTAMP(6) NULL
        AFTER provider_redirect_url;

CREATE INDEX idx_payments_provider_status_expires
    ON payments (
                 provider,
                 status,
                 provider_expires_at
        );