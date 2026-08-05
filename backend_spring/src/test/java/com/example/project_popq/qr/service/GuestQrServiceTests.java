package com.example.project_popq.qr.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.project_popq.qr.config.QrProperties;
import com.example.project_popq.qr.domain.GuestSession;
import com.example.project_popq.qr.domain.QrCode;
import com.example.project_popq.qr.domain.QrCodeStatus;
import com.example.project_popq.qr.repository.GuestSessionRepository;
import com.example.project_popq.qr.repository.QrCodeRepository;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreType;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class GuestQrServiceTests {

    @Test
    void reusesAValidSessionForTheSameQrCode() {
        QrCodeRepository qrCodeRepository = mock(QrCodeRepository.class);
        GuestSessionRepository sessionRepository = mock(
                GuestSessionRepository.class
        );
        OpaqueTokenService tokenService = mock(OpaqueTokenService.class);
        QrCode qrCode = mock(QrCode.class);
        Store store = mock(Store.class);
        GuestSession session = mock(GuestSession.class);
        Instant expiresAt = Instant.now().plusSeconds(3600);

        when(tokenService.hash("qr-token")).thenReturn("qr-hash");
        when(tokenService.hash("session-token")).thenReturn("session-hash");
        when(qrCodeRepository.findByTokenHash("qr-hash"))
                .thenReturn(Optional.of(qrCode));
        when(sessionRepository.findBySessionHash("session-hash"))
                .thenReturn(Optional.of(session));
        when(qrCode.getId()).thenReturn(10L);
        when(qrCode.getStatus()).thenReturn(QrCodeStatus.ACTIVE);
        when(qrCode.getStore()).thenReturn(store);
        when(qrCode.getStoreTable()).thenReturn(null);
        when(store.getId()).thenReturn(20L);
        when(store.getName()).thenReturn("POPQ 스토어");
        when(store.getStoreType()).thenReturn(StoreType.LOCAL_STORE);
        when(store.getBusinessStatus()).thenReturn(BusinessStatus.OPEN);
        when(store.isActive()).thenReturn(true);
        when(store.isOpen()).thenReturn(true);
        when(session.getQrCode()).thenReturn(qrCode);
        when(session.getExpiresAt()).thenReturn(expiresAt);
        when(session.isExpired(org.mockito.ArgumentMatchers.any()))
                .thenReturn(false);

        GuestQrService service = new GuestQrService(
                qrCodeRepository,
                sessionRepository,
                tokenService,
                mock(QrProperties.class)
        );

        GuestQrService.OpenedGuestSession opened = service.open(
                "qr-token",
                "session-token"
        );

        assertThat(opened.rawToken()).isEqualTo("session-token");
        assertThat(opened.expiresAt()).isEqualTo(expiresAt);
        assertThat(opened.context().storeId()).isEqualTo(20L);
        verify(session).touch(org.mockito.ArgumentMatchers.any());
    }
}
