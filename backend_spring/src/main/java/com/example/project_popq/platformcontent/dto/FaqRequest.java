package com.example.project_popq.platformcontent.dto;

import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.ContentStatus;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public final class FaqRequest {
    private FaqRequest() {
    }

    public record Save(
            @NotNull AppAudience audience,
            @NotBlank @Size(max = 50) String category,
            @NotBlank @Size(max = 300) String question,
            @NotBlank @Size(max = 4000) String answer,
            @Min(0) int displayOrder
    ) {
    }

    public record ChangeStatus(@NotNull ContentStatus status) {
    }
}
