ALTER TABLE orders
    ADD COLUMN request_message VARCHAR(100) NULL AFTER order_type;