CREATE TABLE order_messages (
                                order_message_id BIGINT NOT NULL AUTO_INCREMENT,
                                order_id BIGINT NOT NULL,
                                sender_user_id BIGINT NOT NULL,
                                sender_type VARCHAR(30) NOT NULL,
                                content VARCHAR(2000) NOT NULL,
                                read_at TIMESTAMP(6),
                                created_at TIMESTAMP(6) NOT NULL,
                                updated_at TIMESTAMP(6) NOT NULL,
                                PRIMARY KEY (order_message_id),
                                CONSTRAINT ck_order_messages_sender_type
                                    CHECK (sender_type IN ('CUSTOMER', 'SELLER')),
                                CONSTRAINT ck_order_messages_content_not_blank
                                    CHECK (CHAR_LENGTH(TRIM(content)) > 0),
                                CONSTRAINT fk_order_messages_order
                                    FOREIGN KEY (order_id) REFERENCES orders (order_id),
                                CONSTRAINT fk_order_messages_sender_user
                                    FOREIGN KEY (sender_user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_order_messages_order_created
    ON order_messages (order_id, created_at, order_message_id);

CREATE INDEX idx_order_messages_order_sender_read
    ON order_messages (order_id, sender_type, read_at);