CREATE TABLE push_devices (
    push_device_id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    token VARCHAR(512) NOT NULL,
    platform VARCHAR(20) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (push_device_id),
    CONSTRAINT uq_push_devices_token UNIQUE (token),
    CONSTRAINT fk_push_devices_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_push_devices_user_created
    ON push_devices (user_id, created_at);

CREATE TABLE notifications (
    notification_id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    event_id VARCHAR(40) NOT NULL,
    type VARCHAR(30) NOT NULL,
    target_type VARCHAR(30) NOT NULL,
    target_id VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message VARCHAR(500) NOT NULL,
    deep_link VARCHAR(300) NOT NULL,
    is_read BOOLEAN NOT NULL,
    occurred_at TIMESTAMP(6) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (notification_id),
    CONSTRAINT uq_notifications_event UNIQUE (event_id),
    CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_notifications_user_read_occurred
    ON notifications (user_id, is_read, occurred_at);
