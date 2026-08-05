package com.example.project_popq.qr.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.qr.config.QrProperties;
import com.example.project_popq.qr.domain.QrCode;
import com.example.project_popq.qr.domain.QrCodeStatus;
import com.example.project_popq.qr.dto.IssueQrCodeRequest;
import com.example.project_popq.qr.dto.QrDetailResponse;
import com.example.project_popq.qr.dto.QrIssuedResponse;
import com.example.project_popq.qr.dto.QrSummaryResponse;
import com.example.project_popq.qr.dto.ReissueQrCodeRequest;
import com.example.project_popq.qr.repository.QrCodeRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreTable;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.repository.StoreTableRepository;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SellerQrService {

    private final StoreRepository storeRepository;
    private final StoreTableRepository storeTableRepository;
    private final QrCodeRepository qrCodeRepository;
    private final StoreAuthorizationService storeAuthorizationService;
    private final OpaqueTokenService opaqueTokenService;
    private final QrTokenCipher qrTokenCipher;
    private final QrProperties properties;

    @Transactional
    public QrIssuedResponse issue(
            User user,
            Long storeId,
            IssueQrCodeRequest request
    ) {
        requireQrManager(user, storeId);
        Store store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        StoreTable table = findTable(storeId, request.storeTableId());
        validateExpiration(request.expiresAt());

        String rawToken = opaqueTokenService.generate();
        QrCode qrCode = qrCodeRepository.save(
                QrCode.issue(
                        store,
                        table,
                        opaqueTokenService.hash(rawToken),
                        qrTokenCipher.encrypt(rawToken),
                        request.expiresAt()
                )
        );
        return QrIssuedResponse.of(
                qrCode,
                rawToken,
                buildPublicUrl(rawToken)
        );
    }

    @Transactional
    public QrSummaryResponse revoke(User user, Long storeId, Long qrCodeId) {
        requireQrManager(user, storeId);
        QrCode qrCode = qrCodeRepository
                .findDetailedByIdAndStoreId(qrCodeId, storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.QR_NOT_FOUND));
        qrCode.revoke();
        return QrSummaryResponse.from(qrCode);
    }

    @Transactional
    public QrSummaryResponse deactivate(User user, Long storeId, Long qrCodeId) {
        QrCode qrCode = getManagedQr(user, storeId, qrCodeId);
        qrCode.deactivate();
        return QrSummaryResponse.from(qrCode);
    }

    @Transactional
    public QrSummaryResponse activate(User user, Long storeId, Long qrCodeId) {
        QrCode qrCode = getManagedQr(user, storeId, qrCodeId);
        if (!qrCode.activate()) {
            throw new BusinessException(ErrorCode.QR_STATE_INVALID);
        }
        return QrSummaryResponse.from(qrCode);
    }

    @Transactional
    public QrIssuedResponse reissue(
            User user,
            Long storeId,
            Long qrCodeId,
            ReissueQrCodeRequest request
    ) {
        requireQrManager(user, storeId);
        QrCode existing = qrCodeRepository
                .findDetailedByIdAndStoreId(qrCodeId, storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.QR_NOT_FOUND));
        validateExpiration(request.expiresAt());
        existing.revoke();

        String rawToken = opaqueTokenService.generate();
        QrCode replacement = qrCodeRepository.save(
                QrCode.issue(
                        existing.getStore(),
                        existing.getStoreTable(),
                        opaqueTokenService.hash(rawToken),
                        qrTokenCipher.encrypt(rawToken),
                        request.expiresAt()
                )
        );
        return QrIssuedResponse.of(
                replacement,
                rawToken,
                buildPublicUrl(rawToken)
        );
    }

    @Transactional(readOnly = true)
    public List<QrSummaryResponse> findAll(
            User user,
            Long storeId,
            boolean includeArchived
    ) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
        return qrCodeRepository.findAllByStoreIdOrderByIdDesc(storeId)
                .stream()
                .filter(qrCode -> includeArchived || !qrCode.isArchived())
                .map(QrSummaryResponse::from)
                .toList();
    }

    @Transactional
    public QrSummaryResponse archive(User user, Long storeId, Long qrCodeId) {
        QrCode qrCode = getManagedQr(user, storeId, qrCodeId);
        if (qrCode.getStatus() != QrCodeStatus.REVOKED) {
            throw new BusinessException(ErrorCode.QR_STATE_INVALID);
        }
        qrCode.archive(Instant.now());
        return QrSummaryResponse.from(qrCode);
    }

    @Transactional
    public QrSummaryResponse restore(User user, Long storeId, Long qrCodeId) {
        QrCode qrCode = getManagedQr(user, storeId, qrCodeId);
        if (!qrCode.isArchived()) {
            throw new BusinessException(ErrorCode.QR_STATE_INVALID);
        }
        qrCode.restoreFromArchive();
        return QrSummaryResponse.from(qrCode);
    }

    @Transactional(readOnly = true)
    public QrDetailResponse findDetail(User user, Long storeId, Long qrCodeId) {
        QrCode qrCode = getManagedQr(user, storeId, qrCodeId);
        if (!qrCode.isRecoverable()) {
            throw new BusinessException(ErrorCode.QR_ARTIFACT_UNAVAILABLE);
        }
        String rawToken = qrTokenCipher.decrypt(qrCode.getTokenCiphertext());
        if (!opaqueTokenService.hash(rawToken).equals(qrCode.getTokenHash())) {
            throw new BusinessException(ErrorCode.QR_ARTIFACT_UNAVAILABLE);
        }
        return QrDetailResponse.of(qrCode, buildPublicUrl(rawToken));
    }

    private StoreTable findTable(Long storeId, Long storeTableId) {
        if (storeTableId == null) {
            return null;
        }
        return storeTableRepository.findByIdAndStoreId(storeTableId, storeId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.STORE_TABLE_NOT_FOUND
                ));
    }

    private void validateExpiration(Instant expiresAt) {
        if (expiresAt != null && !expiresAt.isAfter(Instant.now())) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
    }

    private void requireQrManager(User user, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER
        );
    }

    private QrCode getManagedQr(User user, Long storeId, Long qrCodeId) {
        requireQrManager(user, storeId);
        return qrCodeRepository.findDetailedByIdAndStoreId(qrCodeId, storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.QR_NOT_FOUND));
    }

    private String buildPublicUrl(String rawToken) {
        String baseUrl = properties.publicBaseUrl().replaceAll("/+$", "");
        return baseUrl + "/q/" + rawToken;
    }
}
