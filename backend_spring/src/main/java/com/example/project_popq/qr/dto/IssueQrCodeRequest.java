package com.example.project_popq.qr.dto;

import java.time.Instant;

public record IssueQrCodeRequest(
        Long storeTableId,
        Instant expiresAt
) {
}

