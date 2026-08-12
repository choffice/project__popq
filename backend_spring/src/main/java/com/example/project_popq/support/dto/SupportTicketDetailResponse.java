package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportTicket;
import java.util.List;

public record SupportTicketDetailResponse(
        SupportTicketSummaryResponse ticket,
        List<SupportMessageResponse> messages
) {
    public static SupportTicketDetailResponse of(
            SupportTicket ticket,
            List<SupportMessageResponse> messages
    ) {
        return new SupportTicketDetailResponse(
                SupportTicketSummaryResponse.from(ticket),
                messages
        );
    }
}
