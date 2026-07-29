package com.example.project_popq.qr;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.qr.domain.QrCode;
import com.example.project_popq.qr.dto.IssueQrCodeRequest;
import com.example.project_popq.qr.dto.QrIssuedResponse;
import com.example.project_popq.qr.dto.ReissueQrCodeRequest;
import com.example.project_popq.qr.repository.QrCodeRepository;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.OpaqueTokenService;
import com.example.project_popq.qr.service.SellerQrService;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class QrSecurityIntegrationTests {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoreRepository storeRepository;

    @Autowired
    private StoreMemberRepository storeMemberRepository;

    @Autowired
    private QrCodeRepository qrCodeRepository;

    @Autowired
    private SellerQrService sellerQrService;

    @Autowired
    private GuestQrService guestQrService;

    @Autowired
    private OpaqueTokenService opaqueTokenService;

    @Test
    void issuedQrStoresOnlyHashAndCreatesGuestSession() {
        SellerStore fixture = createOpenSellerStore("qr-hash@popq.test");

        QrIssuedResponse issued = sellerQrService.issue(
                fixture.seller(),
                fixture.store().getId(),
                new IssueQrCodeRequest(null, Instant.now().plusSeconds(3600))
        );

        QrCode stored = qrCodeRepository.findById(issued.qrCodeId()).orElseThrow();
        assertThat(stored.getTokenHash()).hasSize(64);
        assertThat(stored.getTokenHash()).isNotEqualTo(issued.token());
        assertThat(stored.getTokenHash())
                .isEqualTo(opaqueTokenService.hash(issued.token()));

        GuestQrService.OpenedGuestSession opened = guestQrService.open(issued.token());
        assertThat(opened.context().storeId()).isEqualTo(fixture.store().getId());
        assertThat(guestQrService.resolve(opened.rawToken()).storeId())
                .isEqualTo(fixture.store().getId());
    }

    @Test
    void revokedQrIsRejected() {
        SellerStore fixture = createOpenSellerStore("qr-revoked@popq.test");
        QrIssuedResponse issued = sellerQrService.issue(
                fixture.seller(),
                fixture.store().getId(),
                new IssueQrCodeRequest(null, null)
        );
        sellerQrService.revoke(
                fixture.seller(),
                fixture.store().getId(),
                issued.qrCodeId()
        );

        assertErrorCode(
                () -> guestQrService.open(issued.token()),
                ErrorCode.QR_REVOKED
        );
    }

    @Test
    void inactiveQrIsRejectedAndCanBeReactivated() {
        SellerStore fixture = createOpenSellerStore("qr-deactivated@popq.test");
        QrIssuedResponse issued = sellerQrService.issue(
                fixture.seller(),
                fixture.store().getId(),
                new IssueQrCodeRequest(null, null)
        );
        sellerQrService.deactivate(
                fixture.seller(),
                fixture.store().getId(),
                issued.qrCodeId()
        );

        assertErrorCode(
                () -> guestQrService.open(issued.token()),
                ErrorCode.QR_INACTIVE
        );

        sellerQrService.activate(
                fixture.seller(),
                fixture.store().getId(),
                issued.qrCodeId()
        );
        assertThat(guestQrService.open(issued.token()).context().storeId())
                .isEqualTo(fixture.store().getId());
    }

    @Test
    void expiredQrIsRejected() {
        SellerStore fixture = createOpenSellerStore("qr-expired@popq.test");
        String rawToken = opaqueTokenService.generate();
        qrCodeRepository.save(
                QrCode.issue(
                        fixture.store(),
                        null,
                        opaqueTokenService.hash(rawToken),
                        Instant.now().minusSeconds(1)
                )
        );

        assertErrorCode(
                () -> guestQrService.open(rawToken),
                ErrorCode.QR_EXPIRED
        );
    }

    @Test
    void inactiveStoreQrIsRejected() {
        SellerStore fixture = createOpenSellerStore("qr-inactive@popq.test");
        QrIssuedResponse issued = sellerQrService.issue(
                fixture.seller(),
                fixture.store().getId(),
                new IssueQrCodeRequest(null, null)
        );
        fixture.store().changeStatus(StoreStatus.SUSPENDED);

        assertErrorCode(
                () -> guestQrService.open(issued.token()),
                ErrorCode.QR_INACTIVE
        );
    }

    @Test
    void reissueRevokesOldTokenAndActivatesNewToken() {
        SellerStore fixture = createOpenSellerStore("qr-reissue@popq.test");
        QrIssuedResponse oldQr = sellerQrService.issue(
                fixture.seller(),
                fixture.store().getId(),
                new IssueQrCodeRequest(null, null)
        );

        QrIssuedResponse newQr = sellerQrService.reissue(
                fixture.seller(),
                fixture.store().getId(),
                oldQr.qrCodeId(),
                new ReissueQrCodeRequest(null)
        );

        assertErrorCode(
                () -> guestQrService.open(oldQr.token()),
                ErrorCode.QR_REVOKED
        );
        assertErrorCode(
                () -> sellerQrService.activate(
                        fixture.seller(),
                        fixture.store().getId(),
                        oldQr.qrCodeId()
                ),
                ErrorCode.QR_STATE_INVALID
        );
        assertThat(guestQrService.open(newQr.token()).context().storeId())
                .isEqualTo(fixture.store().getId());
    }

    private SellerStore createOpenSellerStore(String email) {
        User seller = userRepository.save(
                User.create(email, "QR 판매자", PlatformRole.SELLER)
        );
        Store store = Store.create(
                StoreType.LOCAL_STORE,
                "QR 보안 테스트",
                null
        );
        store.changeBusinessStatus(BusinessStatus.OPEN);
        storeRepository.save(store);
        storeMemberRepository.save(
                StoreMember.create(store, seller, StoreRole.OWNER)
        );
        return new SellerStore(seller, store);
    }

    private void assertErrorCode(Runnable operation, ErrorCode expected) {
        assertThatThrownBy(operation::run)
                .isInstanceOfSatisfying(
                        BusinessException.class,
                        exception -> assertThat(exception.getErrorCode())
                                .isEqualTo(expected)
                );
    }

    private record SellerStore(User seller, Store store) {
    }
}
