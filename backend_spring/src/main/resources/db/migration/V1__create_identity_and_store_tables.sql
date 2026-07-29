CREATE TABLE users (
    user_id BIGINT NOT NULL AUTO_INCREMENT,
    email VARCHAR(255),
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(30),
    role VARCHAR(30) NOT NULL,
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE TABLE social_accounts (
    social_account_id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    provider VARCHAR(30) NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (social_account_id),
    CONSTRAINT uq_social_accounts_provider_user UNIQUE (provider, provider_user_id),
    CONSTRAINT fk_social_accounts_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
);

CREATE TABLE seller_profiles (
    seller_profile_id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    business_name VARCHAR(150),
    business_registration_number VARCHAR(30),
    verification_status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (seller_profile_id),
    CONSTRAINT uq_seller_profiles_user UNIQUE (user_id),
    CONSTRAINT fk_seller_profiles_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
);

CREATE TABLE stores (
    store_id BIGINT NOT NULL AUTO_INCREMENT,
    store_type VARCHAR(30) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(1000),
    status VARCHAR(30) NOT NULL,
    business_status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_id)
);

CREATE TABLE store_members (
    store_member_id BIGINT NOT NULL AUTO_INCREMENT,
    store_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role VARCHAR(30) NOT NULL,
    status VARCHAR(30) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (store_member_id),
    CONSTRAINT uq_store_members_store_user UNIQUE (store_id, user_id),
    CONSTRAINT fk_store_members_store
        FOREIGN KEY (store_id) REFERENCES stores (store_id),
    CONSTRAINT fk_store_members_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_store_members_user_status
    ON store_members (user_id, status);

