package com.example.project_popq.inquiry.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record ReadOrderMessagesRequest(
    @NotNull
    @Positive
    Long lastReadMessageId
) {
}