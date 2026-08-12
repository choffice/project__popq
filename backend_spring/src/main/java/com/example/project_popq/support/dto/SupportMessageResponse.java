package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportMessage;
import com.example.project_popq.support.domain.SupportSenderType;
import java.time.Instant;

public record SupportMessageResponse(
        Long supportMessageId,
        Long senderUserId,
        String senderName,
        SupportSenderType senderType,
        String content,
        Instant createdAt
) {
    public static SupportMessageResponse from(SupportMessage message) {
        return new SupportMessageResponse(
                message.getId(),
                message.getSender().getId(),
                message.getSender().getName(),
                message.getSenderType(),
                message.getContent(),
                message.getCreatedAt()
        );
    }
}
