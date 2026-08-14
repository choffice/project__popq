CREATE TABLE store_option_group_templates (
    store_option_group_template_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    min_select INT NOT NULL,
    max_select INT NOT NULL,
    is_required BOOLEAN NOT NULL,
    version BIGINT NOT NULL DEFAULT 1,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_option_group_template_id),
    CONSTRAINT uq_store_option_group_templates_store_name
        UNIQUE (store_id, name),
    CONSTRAINT ck_store_option_group_templates_selection
        CHECK (min_select >= 0 AND max_select >= min_select),
    CONSTRAINT fk_store_option_group_templates_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id)
);

CREATE TABLE store_option_template_options (
    store_option_template_option_id BIGINT NOT NULL AUTO_INCREMENT,
    store_option_group_template_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    additional_price BIGINT NOT NULL,
    display_order INT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_option_template_option_id),
    CONSTRAINT ck_store_option_template_options_price
        CHECK (additional_price >= 0),
    CONSTRAINT fk_store_option_template_options_template
        FOREIGN KEY (store_option_group_template_id)
        REFERENCES store_option_group_templates (store_option_group_template_id)
        ON DELETE CASCADE
);

ALTER TABLE product_option_groups
    ADD COLUMN store_option_group_template_id BIGINT NULL,
    ADD COLUMN applied_template_version BIGINT NULL,
    ADD CONSTRAINT fk_product_option_groups_template
        FOREIGN KEY (store_option_group_template_id)
        REFERENCES store_option_group_templates (store_option_group_template_id)
        ON DELETE SET NULL;

CREATE INDEX idx_product_option_groups_template
    ON product_option_groups (store_option_group_template_id);
