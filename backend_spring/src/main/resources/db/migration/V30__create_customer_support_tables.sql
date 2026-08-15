CREATE TABLE support_faqs
(
    support_faq_id BIGINT        NOT NULL AUTO_INCREMENT,
    question       VARCHAR(500)  NOT NULL,
    answer         VARCHAR(3000) NOT NULL,
    display_order  INT           NOT NULL DEFAULT 0,
    view_count     BIGINT        NOT NULL DEFAULT 0,
    is_popular     BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP(6)  NOT NULL,
    updated_at     TIMESTAMP(6)  NOT NULL,
    PRIMARY KEY (support_faq_id),
    CONSTRAINT ck_support_faqs_question_not_blank
        CHECK (CHAR_LENGTH(TRIM(question)) > 0),
    CONSTRAINT ck_support_faqs_answer_not_blank
        CHECK (CHAR_LENGTH(TRIM(answer)) > 0),
    CONSTRAINT ck_support_faqs_display_order
        CHECK (display_order >= 0),
    CONSTRAINT ck_support_faqs_view_count
        CHECK (view_count >= 0)
);

CREATE INDEX idx_support_faqs_active_popular_order
    ON support_faqs (
                     is_active,
                     is_popular,
                     display_order
        );

CREATE TABLE support_inquiries
(
    support_inquiry_id BIGINT       NOT NULL AUTO_INCREMENT,
    customer_user_id   BIGINT       NOT NULL,
    category           VARCHAR(30)  NOT NULL,
    title              VARCHAR(200) NOT NULL,
    status             VARCHAR(30)  NOT NULL DEFAULT 'RECEIVED',
    answered_at        TIMESTAMP(6),
    closed_at          TIMESTAMP(6),
    created_at         TIMESTAMP(6) NOT NULL,
    updated_at         TIMESTAMP(6) NOT NULL,
    PRIMARY KEY (support_inquiry_id),
    CONSTRAINT ck_support_inquiries_category
        CHECK (
            category IN (
                         'ACCOUNT',
                         'ORDER',
                         'PAYMENT',
                         'COUPON',
                         'APP',
                         'OTHER'
                )
            ),
    CONSTRAINT ck_support_inquiries_status
        CHECK (
            status IN (
                       'RECEIVED',
                       'IN_PROGRESS',
                       'ANSWERED',
                       'CLOSED'
                )
            ),
    CONSTRAINT ck_support_inquiries_title_not_blank
        CHECK (CHAR_LENGTH(TRIM(title)) > 0),
    CONSTRAINT fk_support_inquiries_customer
        FOREIGN KEY (customer_user_id)
            REFERENCES users (user_id)
);

CREATE INDEX idx_support_inquiries_customer_created
    ON support_inquiries (
                          customer_user_id,
                          created_at,
                          support_inquiry_id
        );

CREATE INDEX idx_support_inquiries_status_created
    ON support_inquiries (
                          status,
                          created_at,
                          support_inquiry_id
        );

CREATE TABLE support_inquiry_messages
(
    support_inquiry_message_id BIGINT        NOT NULL AUTO_INCREMENT,
    support_inquiry_id         BIGINT        NOT NULL,
    sender_user_id             BIGINT        NOT NULL,
    sender_type                VARCHAR(30)   NOT NULL,
    content                    VARCHAR(3000) NOT NULL,
    read_at                    TIMESTAMP(6),
    created_at                 TIMESTAMP(6)  NOT NULL,
    updated_at                 TIMESTAMP(6)  NOT NULL,
    PRIMARY KEY (support_inquiry_message_id),
    CONSTRAINT ck_support_inquiry_messages_sender_type
        CHECK (sender_type IN ('CUSTOMER', 'ADMIN')),
    CONSTRAINT ck_support_inquiry_messages_content_not_blank
        CHECK (CHAR_LENGTH(TRIM(content)) > 0),
    CONSTRAINT fk_support_inquiry_messages_inquiry
        FOREIGN KEY (support_inquiry_id)
            REFERENCES support_inquiries (support_inquiry_id),
    CONSTRAINT fk_support_inquiry_messages_sender
        FOREIGN KEY (sender_user_id)
            REFERENCES users (user_id)
);

CREATE INDEX idx_support_inquiry_messages_inquiry_created
    ON support_inquiry_messages (
                                 support_inquiry_id,
                                 created_at,
                                 support_inquiry_message_id
        );

CREATE INDEX idx_support_inquiry_messages_sender_read
    ON support_inquiry_messages (
                                 support_inquiry_id,
                                 sender_type,
                                 read_at
        );

INSERT INTO support_faqs (question,
                          answer,
                          display_order,
                          view_count,
                          is_popular,
                          is_active,
                          created_at,
                          updated_at)
VALUES ('주문을 취소하고 싶어요.',
        '주문 상태에 따라 주문 상세 화면에서 취소할 수 있습니다.',
        1,
        0,
        TRUE,
        TRUE,
        CURRENT_TIMESTAMP(6),
        CURRENT_TIMESTAMP(6)),
       ('결제 수단을 변경할 수 있나요?',
        '결제가 완료된 주문의 결제 수단은 변경할 수 없습니다.',
        2,
        0,
        TRUE,
        TRUE,
        CURRENT_TIMESTAMP(6),
        CURRENT_TIMESTAMP(6)),
       ('환불은 언제 처리되나요?',
        '환불 완료 시점은 결제 수단과 카드사 정책에 따라 달라질 수 있습니다.',
        3,
        0,
        TRUE,
        TRUE,
        CURRENT_TIMESTAMP(6),
        CURRENT_TIMESTAMP(6)),
       ('매장 이용 중 문제가 생겼어요.',
        '주문 관련 문제는 주문 상세의 문의하기 또는 고객센터를 이용해 주세요.',
        4,
        0,
        TRUE,
        TRUE,
        CURRENT_TIMESTAMP(6),
        CURRENT_TIMESTAMP(6)),
       ('쿠폰이 적용되지 않아요.',
        '쿠폰의 사용 기간과 최소 주문 금액, 적용 가능한 매장을 확인해 주세요.',
        5,
        0,
        TRUE,
        TRUE,
        CURRENT_TIMESTAMP(6),
        CURRENT_TIMESTAMP(6)),
       ('회원 정보를 변경하고 싶어요.',
        '마이페이지의 내 정보 관리에서 변경할 수 있습니다.',
        6,
        0,
        TRUE,
        TRUE,
        CURRENT_TIMESTAMP(6),
        CURRENT_TIMESTAMP(6));