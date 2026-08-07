package com.example.project_popq.engagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SellerReviewReplyTemplateRequest(
        @NotBlank @Size(max = 1000) String content
) {
}
