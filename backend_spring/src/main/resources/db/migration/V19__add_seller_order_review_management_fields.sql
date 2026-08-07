ALTER TABLE stores
    ADD COLUMN default_preparation_minutes INT NULL;

ALTER TABLE orders
    ADD COLUMN preparation_minutes INT NULL,
    ADD COLUMN accepted_at TIMESTAMP(6) NULL,
    ADD COLUMN estimated_ready_at TIMESTAMP(6) NULL;

ALTER TABLE reviews
    ADD COLUMN seller_reply VARCHAR(1000) NULL,
    ADD COLUMN seller_replied_at TIMESTAMP(6) NULL,
    ADD COLUMN seller_replied_by_user_id BIGINT NULL,
    ADD CONSTRAINT fk_reviews_seller_replied_by_user
        FOREIGN KEY (seller_replied_by_user_id) REFERENCES users (user_id)
        ON DELETE SET NULL;

CREATE INDEX idx_reviews_store_reply_created
    ON reviews (store_id, seller_replied_at, created_at);
