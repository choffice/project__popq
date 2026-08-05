CREATE TABLE user_roles (
user_id BIGINT NOT NULL,
role VARCHAR(30) NOT NULL,

PRIMARY KEY (user_id, role),

CONSTRAINT fk_user_roles_user
    FOREIGN KEY (user_id)
    REFERENCES users (user_id)
);

INSERT INTO user_roles (user_id, role)
SELECT user_id, role
FROM users;