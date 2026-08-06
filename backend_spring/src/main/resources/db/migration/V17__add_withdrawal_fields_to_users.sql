ALTER TABLE users
    ADD COLUMN withdrawal_requested_at TIMESTAMP(6) NULL,
    ADD COLUMN withdrawal_effective_at TIMESTAMP(6) NULL,
    ADD COLUMN token_valid_after TIMESTAMP(6) NULL;
