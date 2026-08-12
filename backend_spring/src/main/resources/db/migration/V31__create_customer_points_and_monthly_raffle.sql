CREATE TABLE customer_point_transactions (
    customer_point_transaction_id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    transaction_type VARCHAR(30) NOT NULL,
    point_amount BIGINT NOT NULL,
    source_key VARCHAR(100) NOT NULL,
    order_public_id VARCHAR(40) NOT NULL,
    store_name VARCHAR(150) NOT NULL,
    payment_amount BIGINT NOT NULL,
    occurred_at DATETIME(6) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (customer_point_transaction_id),
    UNIQUE KEY uk_customer_point_transactions_source_key (source_key),
    KEY idx_customer_point_transactions_user_occurred (user_id, occurred_at),
    KEY idx_customer_point_transactions_user_order (user_id, order_public_id),
    CONSTRAINT fk_customer_point_transactions_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
);

CREATE TABLE monthly_raffle_rounds (
    monthly_raffle_round_id BIGINT NOT NULL AUTO_INCREMENT,
    round_month DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    winner_entry_id BIGINT NULL,
    drawn_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (monthly_raffle_round_id),
    UNIQUE KEY uk_monthly_raffle_rounds_month (round_month)
);

CREATE TABLE monthly_raffle_entries (
    monthly_raffle_entry_id BIGINT NOT NULL AUTO_INCREMENT,
    round_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    purchased_at DATETIME(6) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (monthly_raffle_entry_id),
    KEY idx_monthly_raffle_entries_round (round_id),
    KEY idx_monthly_raffle_entries_user_round (user_id, round_id),
    CONSTRAINT fk_monthly_raffle_entries_round
        FOREIGN KEY (round_id) REFERENCES monthly_raffle_rounds (monthly_raffle_round_id),
    CONSTRAINT fk_monthly_raffle_entries_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
);
