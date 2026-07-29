CREATE TABLE store_tables (
    store_table_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    table_code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_table_id),
    CONSTRAINT uq_store_tables_store_code UNIQUE (store_id, table_code),
    CONSTRAINT fk_store_tables_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id)
);

CREATE TABLE product_categories (
    product_category_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    display_order INT NOT NULL,
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (product_category_id),
    CONSTRAINT uq_product_categories_store_name UNIQUE (store_id, name),
    CONSTRAINT fk_product_categories_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id)
);

CREATE TABLE products (
    product_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    product_category_id BIGINT NOT NULL,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(1000),
    image_url VARCHAR(1000),
    base_price BIGINT NOT NULL,
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (product_id),
    CONSTRAINT ck_products_base_price CHECK (base_price >= 0),
    CONSTRAINT fk_products_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id),
    CONSTRAINT fk_products_category
        FOREIGN KEY (product_category_id) REFERENCES product_categories (product_category_id)
);

CREATE INDEX idx_products_store_category_status
    ON products (store_id, product_category_id, status);

CREATE TABLE product_option_groups (
    product_option_group_id BIGINT NOT NULL AUTO_INCREMENT,
    product_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    min_select INT NOT NULL,
    max_select INT NOT NULL,
    is_required BOOLEAN NOT NULL,
    display_order INT NOT NULL,
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (product_option_group_id),
    CONSTRAINT ck_product_option_groups_selection
        CHECK (min_select >= 0 AND max_select >= min_select),
    CONSTRAINT fk_product_option_groups_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
);

CREATE TABLE product_options (
    product_option_id BIGINT NOT NULL AUTO_INCREMENT,
    product_option_group_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    additional_price BIGINT NOT NULL,
    display_order INT NOT NULL,
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (product_option_id),
    CONSTRAINT ck_product_options_price CHECK (additional_price >= 0),
    CONSTRAINT uq_product_options_group_name
        UNIQUE (product_option_group_id, name),
    CONSTRAINT fk_product_options_group
        FOREIGN KEY (product_option_group_id)
        REFERENCES product_option_groups (product_option_group_id)
);

CREATE TABLE product_availability (
    product_availability_id BIGINT NOT NULL AUTO_INCREMENT,
    product_id BIGINT NOT NULL,
    sold_out BOOLEAN NOT NULL,
    sales_start_at TIMESTAMP(6),
    sales_end_at TIMESTAMP(6),
    qr_web_enabled BOOLEAN NOT NULL,
    customer_app_enabled BOOLEAN NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (product_availability_id),
    CONSTRAINT uq_product_availability_product UNIQUE (product_id),
    CONSTRAINT fk_product_availability_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
);

CREATE TABLE tags (
    tag_id BIGINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    tag_type VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (tag_id),
    CONSTRAINT uq_tags_name_type UNIQUE (name, tag_type)
);

CREATE TABLE product_tags (
    product_tag_id BIGINT NOT NULL AUTO_INCREMENT,
    product_id BIGINT NOT NULL,
    tag_id BIGINT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (product_tag_id),
    CONSTRAINT uq_product_tags_product_tag UNIQUE (product_id, tag_id),
    CONSTRAINT fk_product_tags_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT fk_product_tags_tag
        FOREIGN KEY (tag_id) REFERENCES tags (tag_id)
);

CREATE TABLE qr_codes (
    qr_code_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    store_table_id BIGINT,
    token_hash VARCHAR(64) NOT NULL,
    status VARCHAR(30) NOT NULL,
    expires_at TIMESTAMP(6),
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (qr_code_id),
    CONSTRAINT uq_qr_codes_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_qr_codes_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id),
    CONSTRAINT fk_qr_codes_store_table
        FOREIGN KEY (store_table_id) REFERENCES store_tables (store_table_id)
);

CREATE INDEX idx_qr_codes_store_status
    ON qr_codes (store_id, status);

CREATE TABLE guest_sessions (
    guest_session_id BIGINT NOT NULL AUTO_INCREMENT,
    qr_code_id BIGINT NOT NULL,
    session_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMP(6) NOT NULL,
    last_seen_at TIMESTAMP(6) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (guest_session_id),
    CONSTRAINT uq_guest_sessions_session_hash UNIQUE (session_hash),
    CONSTRAINT fk_guest_sessions_qr_code
        FOREIGN KEY (qr_code_id) REFERENCES qr_codes (qr_code_id)
);

CREATE INDEX idx_guest_sessions_qr_expires
    ON guest_sessions (qr_code_id, expires_at);
