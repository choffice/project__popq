package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportInquiryMessage;
import com.example.project_popq.support.domain.SupportMessageSenderType;
import java.time.Instant;

public record SupportInquiryMessageResponse(
    Long supportInquiryMessageId,
    Long senderUserId,
    String senderName,
    SupportMessageSenderType senderType,
    String content,
    boolean read,
    Instant readAt,
    Instant createdAt
) {

  public static SupportInquiryMessageResponse from(
      SupportInquiryMessage message
  ) {
    return new SupportInquiryMessageResponse(
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