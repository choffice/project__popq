ALTER TABLE announcements
    ADD COLUMN pinned BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX idx_announcements_store_status_pinned_published
    ON announcements (store_id, status, pinned, published_at);
