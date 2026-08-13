package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportFaq;

public record SupportFaqResponse(
    Long supportFaqId,
    String question,
    String answer,
    int displayOrder,
    long viewCount,
    boolean popular
) {

  public static SupportFaqResponse from(
      SupportFaq faq
  ) {
    return new SupportFaqResponse(
        faq.getId(),
        faq.getQuestion(),
        faq.getAnswer(),
        faq.getDisplayOrder(),
        faq.getViewCount(),
        faq.isPopular()
    );
  }
}