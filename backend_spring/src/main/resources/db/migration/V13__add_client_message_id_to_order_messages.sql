ALTER TABLE order_messages
    ADD COLUMN client_message_id VARCHAR(64) NULL
        AFTER sender_type;

CREATE UNIQUE INDEX uk_order_messages_idempotency
    ON order_messages (
                       order_id,
                       sender_user_id,
                       client_message_id
        );