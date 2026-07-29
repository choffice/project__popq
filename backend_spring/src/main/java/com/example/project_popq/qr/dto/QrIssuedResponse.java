package com.example.project_popq.qr.dto;

import com.example.project_popq.qr.domain.QrCode;
import com.example.project_popq.qr.domain.QrCodeStatus;
import java.time.Instant;

public record QrIssuedResponse(
        Long qrCodeId,
        Long storeId,
        Long storeTableId,
        String token,
        String publicUrl,
        QrCodeStatus status,
        Instant expiresAt
) {
    public static QrIssuedResponse of(
            QrCode qrCode,
            String token,
            String publicUrl
    ) {
        return new QrIssuedResponse(
                qrCode.getId(),
                qrCode.getStore().getId(),
                qrCode.getStoreTable() == null
                        ? null
                        : qrCode.getStoreTable().getId(),
                token,
                publicUrl,
                qrCode.getStatus(),
                qrCode.getExpiresAt()
        );
    }
}

