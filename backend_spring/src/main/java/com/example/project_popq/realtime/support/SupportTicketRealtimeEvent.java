package com.example.project_popq.realtime.support;

import com.example.project_popq.support.domain.SupportRequesterType;
import com.example.project_popq.support.domain.SupportSenderType;
import com.example.project_popq.support.domain.SupportTicketStatus;
import java.time.Instant;

public record SupportTicketRealtimeEvent(
    String eventId,
    SupportTicketRealtimeEventType eventType,
    Long ticketId,
    Long requesterUserId,
    SupportRequesterType requesterType,
    SupportSenderType senderType,
    SupportTicketStatus status,
    Instant occurredAt
) {
}