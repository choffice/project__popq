ALTER TABLE support_tickets
    ADD COLUMN requester_read_at TIMESTAMP(6) NULL AFTER last_message_at;

-- 기존 문의는 배포 시점에 갑자기 과거 답변이 모두 미읽음으로 표시되지 않도록
-- 현재 마지막 메시지까지 읽은 상태로 시작합니다.
UPDATE support_tickets
SET requester_read_at = last_message_at
WHERE requester_read_at IS NULL;
