ALTER TABLE users
    ADD CONSTRAINT uq_users_phone UNIQUE (phone);
