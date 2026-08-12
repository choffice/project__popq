package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportInquiry;
import com.example.project_popq.support.domain.SupportInquiryMessage;
import java.util.List;

public record SupportInquiryDetailResponse(
    SupportInquirySummaryResponse inquiry,
    List<SupportInquiryMessageResponse> messages
) {

  public static SupportInquiryDetailResponse from(
      SupportInquiry inquiry,
      List<SupportInquiryMessage> messages,
      long unreadMessageCount
  ) {
    return new SupportInquiryDetailResponse(
        SupportInquirySummaryResponse.from(
            inquiry,
            unreadMessageCount
        ),
        messages.stream()
            .map(SupportInquiryMessageResponse::from)
            .toList()
    );
  }
}