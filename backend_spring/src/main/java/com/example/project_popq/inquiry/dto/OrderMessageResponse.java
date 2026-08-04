package com.example.project_popq.inquiry.dto;

import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.domain.OrderMessage;
import java.time.Instant;

public record OrderMessageResponse(
    Long orderMessageId,
    Long senderUserId,
    String senderName,
    MessageSenderType senderType,
    String content,
    boolean read,
    Instant readAt,
    Instant createdAt
) {

  public static OrderMessageResponse from(OrderMessage message) {
    return new OrderMessageResponse(
        message.getId(),
        message.getSender().getId(),
        message.getSender().getName(),
        message.getSenderType(),
        message.getContent(),
        message.isRead(),
        message.getReadAt(),
        message.getCreatedAt()
    );
  }
}