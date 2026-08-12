package com.example.project_popq.platformcontent.dto;

import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.ContentStatus;
import com.example.project_popq.platformcontent.domain.Faq;
import java.time.Instant;

public record FaqResponse(
        Long faqId,
        AppAudience audience,
        String category,
        String question,
        String answer,
        int displayOrder,
        ContentStatus status,
        String authorName,
        Instant createdAt,
        Instant updatedAt
) {
    public static FaqResponse from(Faq faq) {
        return new FaqResponse(
                faq.getId(),
                faq.getAudience(),
                faq.getCategory(),
                faq.getQuestion(),
                faq.getAnswer(),
                faq.getDisplayOrder(),
                faq.getStatus(),
                faq.getAuthor().getName(),
                faq.getCreatedAt(),
                faq.getUpdatedAt()
        );
    }
}
