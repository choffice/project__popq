CREATE TABLE customer_activity_sources (
    customer_activity_source_id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    store_id BIGINT NOT NULL,
    activity_type VARCHAR(30) NOT NULL,
    source_type VARCHAR(30) NOT NULL,
    source_key VARCHAR(100) NOT NULL,
    activity_date DATE NOT NULL,
    active BOOLEAN NOT NULL,
    occurred_at TIMESTAMP(6) NOT NULL,
    revoked_at TIMESTAMP(6),
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (customer_activity_source_id),
    CONSTRAINT uq_customer_activity_source UNIQUE (source_type, source_key),
    CONSTRAINT fk_customer_activity_source_user
        FOREIGN KEY (user_id) REFERENCES users (user_id),
    CONSTRAINT fk_customer_activity_source_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id)
);

CREATE INDEX idx_customer_activity_user_active_date
    ON customer_activity_sources (user_id, active, activity_date);

CREATE INDEX idx_customer_activity_counting
    ON customer_activity_sources (
        user_id,
        active,
        activity_type,
        store_id,
        activity_date
    );

INSERT INTO customer_activity_sources (
    user_id,
    store_id,
    activity_type,
    source_type,
    source_key,
    activity_date,
    active,
    occurred_at,
    revoked_at,
    created_at,
    updated_at
)
SELECT
    o.user_id,
    o.store_id,
    'STORE_PURCHASE',
    'ORDER',
    o.order_public_id,
    DATE(DATE_ADD(p.approved_at, INTERVAL 9 HOUR)),
    TRUE,
    p.approved_at,
    NULL,
    p.approved_at,
    p.approved_at
FROM orders o
JOIN payments p ON p.order_id = o.order_id
WHERE o.user_id IS NOT NULL
  AND p.approved_at IS NOT NULL
  AND p.status = 'PAID';
