package com.example.project_popq.qr.dto;

import java.time.Instant;

public record ReissueQrCodeRequest(
        Instant expiresAt
) {
}

