CREATE TABLE store_interests (
    store_interest_id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    store_id BIGINT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_interest_id),
    CONSTRAINT uq_store_interests_user_store UNIQUE (user_id, store_id),
    CONSTRAINT fk_store_interests_user
        FOREIGN KEY (user_id) REFERENCES users (user_id),
    CONSTRAINT fk_store_interests_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id)
);

CREATE INDEX idx_store_interests_user_created
    ON store_interests (user_id, created_at);

CREATE TABLE reviews (
    review_id BIGINT NOT NULL AUTO_INCREMENT,
    order_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    store_id BIGINT NOT NULL,
    rating INT NOT NULL,
    content VARCHAR(1000),
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (review_id),
    CONSTRAINT uq_reviews_order UNIQUE (order_id),
    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_reviews_user
        FOREIGN KEY (user_id) REFERENCES users (user_id),
    CONSTRAINT fk_reviews_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id),
    CONSTRAINT ck_reviews_rating CHECK (rating >= 1 AND rating <= 5)
);

CREATE INDEX idx_reviews_store_status_created
    ON reviews (store_id, status, created_at);

CREATE INDEX idx_reviews_user_created
    ON reviews (user_id, created_at);
