CREATE TABLE admin_audit_logs (
    admin_audit_log_id BIGINT NOT NULL AUTO_INCREMENT,
    admin_user_id BIGINT NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_id BIGINT NOT NULL,
    action VARCHAR(50) NOT NULL,
    before_value VARCHAR(100),
    after_value VARCHAR(100),
    reason VARCHAR(500),
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (admin_audit_log_id),
    CONSTRAINT fk_admin_audit_logs_admin
        FOREIGN KEY (admin_user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_admin_audit_logs_target
    ON admin_audit_logs (target_type, target_id, created_at);

CREATE TABLE platform_announcements (
    platform_announcement_id BIGINT NOT NULL AUTO_INCREMENT,
    audience VARCHAR(30) NOT NULL,
    title VARCHAR(200) NOT NULL,
    content VARCHAR(4000) NOT NULL,
    status VARCHAR(30) NOT NULL,
    publish_start_at TIMESTAMP(6),
    publish_end_at TIMESTAMP(6),
    author_user_id BIGINT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (platform_announcement_id),
    CONSTRAINT fk_platform_announcements_author
        FOREIGN KEY (author_user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_platform_announcements_exposure
    ON platform_announcements (audience, status, publish_start_at, publish_end_at);

CREATE TABLE faqs (
    faq_id BIGINT NOT NULL AUTO_INCREMENT,
    audience VARCHAR(30) NOT NULL,
    category VARCHAR(50) NOT NULL,
    question VARCHAR(300) NOT NULL,
    answer VARCHAR(4000) NOT NULL,
    display_order INT NOT NULL,
    status VARCHAR(30) NOT NULL,
    author_user_id BIGINT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (faq_id),
    CONSTRAINT fk_faqs_author
        FOREIGN KEY (author_user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_faqs_exposure
    ON faqs (audience, status, category, display_order);

CREATE TABLE support_tickets (
    support_ticket_id BIGINT NOT NULL AUTO_INCREMENT,
    requester_user_id BIGINT NOT NULL,
    requester_type VARCHAR(30) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subject VARCHAR(200) NOT NULL,
    status VARCHAR(40) NOT NULL,
    last_message_at TIMESTAMP(6) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (support_ticket_id),
    CONSTRAINT fk_support_tickets_requester
        FOREIGN KEY (requester_user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_support_tickets_admin_list
    ON support_tickets (status, requester_type, category, last_message_at);

CREATE INDEX idx_support_tickets_requester
    ON support_tickets (requester_user_id, last_message_at);

CREATE TABLE support_messages (
    support_message_id BIGINT NOT NULL AUTO_INCREMENT,
    support_ticket_id BIGINT NOT NULL,
    sender_user_id BIGINT NOT NULL,
    sender_type VARCHAR(30) NOT NULL,
    content VARCHAR(4000) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL,
    updated_at TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (support_message_id),
    CONSTRAINT fk_support_messages_ticket
        FOREIGN KEY (support_ticket_id) REFERENCES support_tickets (support_ticket_id),
    CONSTRAINT fk_support_messages_sender
        FOREIGN KEY (sender_user_id) REFERENCES users (user_id)
);

CREATE INDEX idx_support_messages_ticket_created
    ON support_messages (support_ticket_id, created_at, support_message_id);
