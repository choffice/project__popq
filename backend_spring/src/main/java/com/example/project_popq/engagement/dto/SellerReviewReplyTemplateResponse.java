package com.example.project_popq.engagement.dto;

import com.example.project_popq.engagement.domain.SellerReviewReplyTemplate;

public record SellerReviewReplyTemplateResponse(
        Long templateId,
        String content
) {
    public static SellerReviewReplyTemplateResponse from(
            SellerReviewReplyTemplate template
    ) {
        return new SellerReviewReplyTemplateResponse(
                template.getId(),
                template.getContent()
        );
    }
}
