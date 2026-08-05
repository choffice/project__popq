ALTER TABLE qr_codes
    ADD COLUMN archived_at TIMESTAMP(6);

CREATE INDEX idx_qr_codes_store_archived
    ON qr_codes (store_id, archived_at);
