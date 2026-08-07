package com.example.project_popq.engagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SellerReviewReplyRequest(
        @NotBlank @Size(max = 1000) String reply
) {
}
