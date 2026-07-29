package com.example.project_popq.store.dto;

import com.example.project_popq.store.domain.BusinessStatus;
import jakarta.validation.constraints.NotNull;

public record ChangeBusinessStatusRequest(
        @NotNull BusinessStatus businessStatus
) {
}

