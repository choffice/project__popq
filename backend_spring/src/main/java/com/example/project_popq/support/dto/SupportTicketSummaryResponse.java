package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportCategory;
import com.example.project_popq.support.domain.SupportRequesterType;
import com.example.project_popq.support.domain.SupportTicket;
import com.example.project_popq.support.domain.SupportTicketStatus;
import java.time.Instant;

public record SupportTicketSummaryResponse(
        Long supportTicketId,
        Long requesterUserId,
        String requesterName,
        String requesterEmail,
        SupportRequesterType requesterType,
        SupportCategory category,
        String subject,
        SupportTicketStatus status,
        Instant lastMessageAt,
        Instant createdAt,
        long unreadMessageCount
) {
    public static SupportTicketSummaryResponse from(SupportTicket ticket) {
        return from(ticket, 0L);
    }

    public static SupportTicketSummaryResponse from(
            SupportTicket ticket,
            long unreadMessageCount
    ) {
        return new SupportTicketSummaryResponse(
                ticket.getId(),
                ticket.getRequester().getId(),
                ticket.getRequester().getName(),
                ticket.getRequester().getEmail(),
                ticket.getRequesterType(),
                ticket.getCategory(),
                ticket.getSubject(),
                ticket.getStatus(),
                ticket.getLastMessageAt(),
                ticket.getCreatedAt(),
                Math.max(0L, unreadMessageCount)
        );
    }
}
