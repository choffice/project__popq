package com.example.project_popq.support.dto;

import com.example.project_popq.support.domain.SupportCategory;
import com.example.project_popq.support.domain.SupportRequesterType;
import com.example.project_popq.support.domain.SupportTicketStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public final class SupportTicketRequest {
    private SupportTicketRequest() {
    }

    public record Create(
            @NotNull SupportRequesterType requesterType,
            @NotNull SupportCategory category,
            @NotBlank @Size(max = 200) String subject,
            @NotBlank @Size(max = 4000) String content
    ) {
    }

    public record Message(@NotBlank @Size(max = 4000) String content) {
    }

    public record ChangeStatus(@NotNull SupportTicketStatus status) {
    }
}
