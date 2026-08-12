package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportInquiry;
import com.example.project_popq.support.domain.SupportInquiryCategory;
import com.example.project_popq.support.domain.SupportInquiryStatus;
import java.time.Instant;

public record SupportInquirySummaryResponse(
    Long supportInquiryId,
    Long customerUserId,
    String customerName,
    String customerEmail,
    SupportInquiryCategory category,
    String title,
    SupportInquiryStatus status,
    long unreadMessageCount,
    Instant answeredAt,
    Instant closedAt,
    Instant createdAt,
    Instant updatedAt
) {

  public static SupportInquirySummaryResponse from(
      SupportInquiry inquiry,
      long unreadMessageCount
  ) {
    return new SupportInquirySummaryResponse(
        inquiry.getId(),
        inquiry.getCustomer().getId(),
        inquiry.getCustomer().getName(),
        inquiry.getCustomer().getEmail(),
        inquiry.getCategory(),
        inquiry.getTitle(),
        inquiry.getStatus(),
        unreadMessageCount,
        inquiry.getAnsweredAt(),
        inquiry.getClosedAt(),
        inquiry.getCreatedAt(),
        inquiry.getUpdatedAt()
    );
  }
}