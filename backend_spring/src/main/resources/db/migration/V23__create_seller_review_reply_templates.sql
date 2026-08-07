CREATE TABLE seller_review_reply_templates (
    seller_review_reply_template_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    content VARCHAR(1000) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (seller_review_reply_template_id),
    CONSTRAINT fk_seller_review_reply_templates_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id) ON DELETE CASCADE
);

CREATE INDEX idx_seller_review_reply_templates_store
    ON seller_review_reply_templates (store_id, seller_review_reply_template_id);
