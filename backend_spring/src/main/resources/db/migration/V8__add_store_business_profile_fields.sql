ALTER TABLE stores
    ADD COLUMN representative_category VARCHAR(50),
    ADD COLUMN detail_address VARCHAR(255),
    ADD COLUMN image_url VARCHAR(1000),
    ADD COLUMN phone VARCHAR(30),
    ADD COLUMN open_time TIME,
    ADD COLUMN close_time TIME,
    ADD COLUMN closed_days VARCHAR(100),
    ADD COLUMN takeout_available BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN dine_in_available BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN order_accepting_enabled BOOLEAN NOT NULL DEFAULT TRUE;