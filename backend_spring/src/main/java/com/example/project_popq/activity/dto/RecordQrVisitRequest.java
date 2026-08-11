package com.example.project_popq.activity.dto;

import jakarta.validation.constraints.NotBlank;

public record RecordQrVisitRequest(
        @NotBlank String qrToken
) {
}
