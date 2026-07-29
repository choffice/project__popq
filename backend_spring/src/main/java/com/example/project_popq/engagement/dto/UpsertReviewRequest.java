package com.example.project_popq.engagement.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record UpsertReviewRequest(
        @Min(1) @Max(5) int rating,
        @Size(max = 1000) String content
) {
}
