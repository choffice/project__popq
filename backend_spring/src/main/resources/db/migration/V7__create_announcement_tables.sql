CREATE TABLE announcements (
    announcement_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    title VARCHAR(200) NOT NULL,
    content VARCHAR(2000) NOT NULL,
    status VARCHAR(30) NOT NULL,
    published_at TIMESTAMP(6) NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (announcement_id),
    CONSTRAINT fk_announcements_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id)
);

CREATE INDEX idx_announcements_store_status_created
    ON announcements (store_id, status, created_at);

