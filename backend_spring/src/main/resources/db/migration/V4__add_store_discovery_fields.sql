ALTER TABLE stores
    ADD COLUMN address VARCHAR(255);

ALTER TABLE stores
    ADD COLUMN latitude DECIMAL(10, 7);

ALTER TABLE stores
    ADD COLUMN longitude DECIMAL(10, 7);

CREATE TABLE store_tags (
    store_tag_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    tag_id BIGINT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_tag_id),
    CONSTRAINT uq_store_tags_store_tag UNIQUE (store_id, tag_id),
    CONSTRAINT fk_store_tags_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id),
    CONSTRAINT fk_store_tags_tag
        FOREIGN KEY (tag_id) REFERENCES tags (tag_id)
);

CREATE INDEX idx_stores_public_search
    ON stores (status, business_status);

CREATE INDEX idx_store_tags_tag_store
    ON store_tags (tag_id, store_id);
