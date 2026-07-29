CREATE TABLE orders (
    order_id BIGINT NOT NULL AUTO_INCREMENT,
    order_public_id VARCHAR(40) NOT NULL,
    user_id BIGINT,
    guest_session_id BIGINT,
    store_id BIGINT NOT NULL,
    order_type VARCHAR(30) NOT NULL,
    status VARCHAR(30) NOT NULL,
    subtotal_amount BIGINT NOT NULL,
    discount_amount BIGINT NOT NULL,
    tax_amount BIGINT NOT NULL,
    service_fee_amount BIGINT NOT NULL,
    total_amount BIGINT NOT NULL,
    idempotency_key VARCHAR(100) NOT NULL,
    request_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMP(6) NOT NULL,
    version BIGINT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (order_id),
    CONSTRAINT uq_orders_public_id UNIQUE (order_public_id),
    CONSTRAINT uq_orders_idempotency_key UNIQUE (idempotency_key),
    CONSTRAINT ck_orders_owner
        CHECK (
            (user_id IS NOT NULL AND guest_session_id IS NULL)
            OR (user_id IS NULL AND guest_session_id IS NOT NULL)
        ),
    CONSTRAINT ck_orders_amounts
        CHECK (
            subtotal_amount >= 0
            AND discount_amount >= 0
            AND tax_amount >= 0
            AND service_fee_amount >= 0
            AND total_amount >= 0
        ),
    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id) REFERENCES users (user_id),
    CONSTRAINT fk_orders_guest_session
        FOREIGN KEY (guest_session_id) REFERENCES guest_sessions (guest_session_id),
    CONSTRAINT fk_orders_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id)
);

CREATE INDEX idx_orders_store_status_created
    ON orders (store_id, status, created_at);

CREATE INDEX idx_orders_guest_session_created
    ON orders (guest_session_id, created_at);

CREATE TABLE order_items (
    order_item_id BIGINT NOT NULL AUTO_INCREMENT,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    product_name_snapshot VARCHAR(150) NOT NULL,
    product_image_url_snapshot VARCHAR(1000),
    unit_price_snapshot BIGINT NOT NULL,
    quantity INT NOT NULL,
    item_total_price BIGINT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (order_item_id),
    CONSTRAINT ck_order_items_quantity CHECK (quantity > 0),
    CONSTRAINT ck_order_items_amounts
        CHECK (unit_price_snapshot >= 0 AND item_total_price >= 0),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
);

CREATE TABLE order_item_options (
    order_item_option_id BIGINT NOT NULL AUTO_INCREMENT,
    order_item_id BIGINT NOT NULL,
    product_option_id BIGINT NOT NULL,
    option_group_name_snapshot VARCHAR(100) NOT NULL,
    option_name_snapshot VARCHAR(100) NOT NULL,
    option_price_snapshot BIGINT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (order_item_option_id),
    CONSTRAINT ck_order_item_options_price CHECK (option_price_snapshot >= 0),
    CONSTRAINT fk_order_item_options_item
        FOREIGN KEY (order_item_id) REFERENCES order_items (order_item_id),
    CONSTRAINT fk_order_item_options_option
        FOREIGN KEY (product_option_id) REFERENCES product_options (product_option_id)
);

CREATE TABLE order_status_histories (
    order_status_history_id BIGINT NOT NULL AUTO_INCREMENT,
    order_id BIGINT NOT NULL,
    previous_status VARCHAR(30),
    current_status VARCHAR(30) NOT NULL,
    actor_type VARCHAR(30) NOT NULL,
    actor_id BIGINT,
    reason VARCHAR(500),
    changed_at TIMESTAMP(6) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (order_status_history_id),
    CONSTRAINT fk_order_status_histories_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

CREATE INDEX idx_order_status_histories_order_changed
    ON order_status_histories (order_id, changed_at);

CREATE TABLE payments (
    payment_id BIGINT NOT NULL AUTO_INCREMENT,
    order_id BIGINT NOT NULL,
    provider VARCHAR(30) NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    requested_amount BIGINT NOT NULL,
    approved_amount BIGINT,
    status VARCHAR(30) NOT NULL,
    provider_payment_key VARCHAR(255),
    idempotency_key VARCHAR(100) NOT NULL,
    approved_at TIMESTAMP(6),
    canceled_at TIMESTAMP(6),
    failure_code VARCHAR(100),
    failure_message VARCHAR(500),
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (payment_id),
    CONSTRAINT uq_payments_order UNIQUE (order_id),
    CONSTRAINT uq_payments_idempotency_key UNIQUE (idempotency_key),
    CONSTRAINT uq_payments_provider_key
        UNIQUE (provider, provider_payment_key),
    CONSTRAINT ck_payments_amounts
        CHECK (
            requested_amount >= 0
            AND (approved_amount IS NULL OR approved_amount >= 0)
        ),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

CREATE TABLE payment_transactions (
    payment_transaction_id BIGINT NOT NULL AUTO_INCREMENT,
    payment_id BIGINT NOT NULL,
    transaction_type VARCHAR(30) NOT NULL,
    status VARCHAR(30) NOT NULL,
    request_payload TEXT,
    response_payload TEXT,
    failure_code VARCHAR(100),
    failure_message VARCHAR(500),
    occurred_at TIMESTAMP(6) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (payment_transaction_id),
    CONSTRAINT fk_payment_transactions_payment
        FOREIGN KEY (payment_id) REFERENCES payments (payment_id)
);

CREATE INDEX idx_payment_transactions_payment_occurred
    ON payment_transactions (payment_id, occurred_at);

CREATE TABLE refunds (
    refund_id BIGINT NOT NULL AUTO_INCREMENT,
    payment_id BIGINT NOT NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(500) NOT NULL,
    requester_type VARCHAR(30) NOT NULL,
    requester_id BIGINT,
    status VARCHAR(30) NOT NULL,
    provider_refund_key VARCHAR(255),
    requested_at TIMESTAMP(6) NOT NULL,
    completed_at TIMESTAMP(6),
    failure_code VARCHAR(100),
    failure_message VARCHAR(500),
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (refund_id),
    CONSTRAINT ck_refunds_amount CHECK (amount >= 0),
    CONSTRAINT uq_refunds_provider_key UNIQUE (provider_refund_key),
    CONSTRAINT fk_refunds_payment
        FOREIGN KEY (payment_id) REFERENCES payments (payment_id)
);

CREATE INDEX idx_refunds_payment_status
    ON refunds (payment_id, status);
