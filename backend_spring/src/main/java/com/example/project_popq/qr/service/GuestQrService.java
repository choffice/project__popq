package com.example.project_popq.qr.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.qr.config.QrProperties;
import com.example.project_popq.qr.domain.GuestSession;
import com.example.project_popq.qr.domain.QrCode;
import com.example.project_popq.qr.domain.QrCodeStatus;
import com.example.project_popq.qr.dto.QrContextResponse;
import com.example.project_popq.qr.repository.GuestSessionRepository;
import com.example.project_popq.qr.repository.QrCodeRepository;
import java.time.Duration;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class GuestQrService {

    private final QrCodeRepository qrCodeRepository;
    private final GuestSessionRepository guestSessionRepository;
    private final OpaqueTokenService opaqueTokenService;
    private final QrProperties properties;

    @Transactional
    public OpenedGuestSession open(String rawQrToken) {
        QrCode qrCode = findAndValidateQr(rawQrToken, Instant.now());
        Instant now = Instant.now();
        Instant expiresAt = now.plus(properties.guestSessionTtl());
        if (qrCode.getExpiresAt() != null && qrCode.getExpiresAt().isBefore(expiresAt)) {
            expiresAt = qrCode.getExpiresAt();
        }

        String rawSessionToken = opaqueTokenService.generate();
        GuestSession session = guestSessionRepository.save(
                GuestSession.create(
                        qrCode,
                        opaqueTokenService.hash(rawSessionToken),
                        expiresAt,
                        now
                )
        );
        return new OpenedGuestSession(
                rawSessionToken,
                session.getExpiresAt(),
                QrContextResponse.of(qrCode, session.getExpiresAt())
        );
    }

    @Transactional
    public ResolvedGuestSession resolve(String rawSessionToken) {
        if (rawSessionToken == null || rawSessionToken.isBlank()) {
            throw new BusinessException(ErrorCode.GUEST_SESSION_INVALID);
        }
        GuestSession session = guestSessionRepository
                .findBySessionHash(opaqueTokenService.hash(rawSessionToken))
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.GUEST_SESSION_INVALID
                ));
        Instant now = Instant.now();
        if (session.isExpired(now)) {
            throw new BusinessException(ErrorCode.GUEST_SESSION_EXPIRED);
        }
        validateQr(session.getQrCode(), now);
        session.touch(now);
        return new ResolvedGuestSession(
                session.getId(),
                session.getQrCode().getStore().getId(),
                QrContextResponse.of(session.getQrCode(), session.getExpiresAt())
        );
    }

    public Duration cookieMaxAge(Instant expiresAt) {
        Duration duration = Duration.between(Instant.now(), expiresAt);
        return duration.isNegative() ? Duration.ZERO : duration;
    }

    private QrCode findAndValidateQr(String rawQrToken, Instant now) {
        if (rawQrToken == null || rawQrToken.isBlank()) {
            throw new BusinessException(ErrorCode.QR_NOT_FOUND);
        }
        QrCode qrCode = qrCodeRepository
                .findByTokenHash(opaqueTokenService.hash(rawQrToken))
                .orElseThrow(() -> new BusinessException(ErrorCode.QR_NOT_FOUND));
        validateQr(qrCode, now);
        return qrCode;
    }

    private void validateQr(QrCode qrCode, Instant now) {
        if (qrCode.getStatus() == QrCodeStatus.REVOKED) {
            throw new BusinessException(ErrorCode.QR_REVOKED);
        }
        if (qrCode.getStatus() == QrCodeStatus.INACTIVE) {
            throw new BusinessException(ErrorCode.QR_INACTIVE);
        }
        if (qrCode.isExpired(now)) {
            throw new BusinessException(ErrorCode.QR_EXPIRED);
        }
        if (!qrCode.getStore().isActive()) {
            throw new BusinessException(ErrorCode.QR_INACTIVE);
        }
        if (!qrCode.getStore().isOpen()) {
            throw new BusinessException(ErrorCode.STORE_NOT_OPEN);
        }
        if (qrCode.getStoreTable() != null && !qrCode.getStoreTable().isActive()) {
            throw new BusinessException(ErrorCode.QR_INACTIVE);
        }
    }

    public record OpenedGuestSession(
            String rawToken,
            Instant expiresAt,
            QrContextResponse context
    ) {
    }

    public record ResolvedGuestSession(
            Long guestSessionId,
            Long storeId,
            QrContextResponse context
    ) {
    }
}
