CREATE TABLE store_business_hours (
    store_business_hour_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    day_of_week VARCHAR(20) NOT NULL,
    is_closed BOOLEAN NOT NULL DEFAULT FALSE,
    is_24_hours BOOLEAN NOT NULL DEFAULT FALSE,
    open_time TIME NULL,
    close_time TIME NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_business_hour_id),
    CONSTRAINT uq_store_business_hours_store_day UNIQUE (store_id, day_of_week),
    CONSTRAINT fk_store_business_hours_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id) ON DELETE CASCADE
);

CREATE INDEX idx_store_business_hours_store
    ON store_business_hours (store_id);

CREATE TABLE store_closure_rules (
    store_closure_rule_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    rule_type VARCHAR(30) NOT NULL,
    week_of_month INT NULL,
    day_of_week VARCHAR(20) NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_closure_rule_id),
    CONSTRAINT fk_store_closure_rules_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id) ON DELETE CASCADE
);

CREATE INDEX idx_store_closure_rules_store
    ON store_closure_rules (store_id);

CREATE TABLE store_schedule_exceptions (
    store_schedule_exception_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    exception_type VARCHAR(30) NOT NULL,
    memo VARCHAR(255) NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_schedule_exception_id),
    CONSTRAINT fk_store_schedule_exceptions_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id) ON DELETE CASCADE
);

CREATE INDEX idx_store_schedule_exceptions_store_dates
    ON store_schedule_exceptions (store_id, start_date, end_date);

INSERT INTO store_business_hours (
    store_id,
    day_of_week,
    is_closed,
    is_24_hours,
    open_time,
    close_time,
    created_at,
    updated_at
)
SELECT
    stores.store_id,
    days.day_of_week,
    CASE
        WHEN FIND_IN_SET(days.day_of_week, COALESCE(stores.closed_days, '')) > 0
            THEN TRUE
        ELSE FALSE
    END,
    CASE
        WHEN stores.open_time IS NOT NULL
            AND stores.close_time IS NOT NULL
            AND stores.open_time = stores.close_time
            AND FIND_IN_SET(days.day_of_week, COALESCE(stores.closed_days, '')) = 0
            THEN TRUE
        ELSE FALSE
    END,
    CASE
        WHEN FIND_IN_SET(days.day_of_week, COALESCE(stores.closed_days, '')) > 0
            THEN NULL
        WHEN stores.open_time IS NOT NULL
            AND stores.close_time IS NOT NULL
            AND stores.open_time = stores.close_time
            THEN NULL
        ELSE stores.open_time
    END,
    CASE
        WHEN FIND_IN_SET(days.day_of_week, COALESCE(stores.closed_days, '')) > 0
            THEN NULL
        WHEN stores.open_time IS NOT NULL
            AND stores.close_time IS NOT NULL
            AND stores.open_time = stores.close_time
            THEN NULL
        ELSE stores.close_time
    END,
    CURRENT_TIMESTAMP(6),
    CURRENT_TIMESTAMP(6)
FROM stores
CROSS JOIN (
    SELECT 'MONDAY' AS day_of_week
    UNION ALL SELECT 'TUESDAY'
    UNION ALL SELECT 'WEDNESDAY'
    UNION ALL SELECT 'THURSDAY'
    UNION ALL SELECT 'FRIDAY'
    UNION ALL SELECT 'SATURDAY'
    UNION ALL SELECT 'SUNDAY'
) days;
