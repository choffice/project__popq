package com.example.project_popq.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.admin.dto.AdminOverviewResponse;
import com.example.project_popq.admin.service.AdminOperationsService;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.seller.domain.SellerProfile;
import com.example.project_popq.seller.domain.SellerVerificationStatus;
import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.domain.UserStatus;
import com.example.project_popq.user.repository.UserRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class AdminOperationsIntegrationTests {

    @Autowired
    private AdminOperationsService adminOperationsService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private SellerProfileRepository sellerProfileRepository;

    @Autowired
    private StoreRepository storeRepository;

    @Test
    void adminCanReviewAndChangeUserSellerAndStoreStatuses() {
        User admin = createUser(PlatformRole.ADMIN, "관리자");
        User seller = createUser(PlatformRole.SELLER, "판매자");
        SellerProfile profile = sellerProfileRepository.save(
                SellerProfile.createPending(seller)
        );
        Store store = storeRepository.save(
                Store.create(StoreType.LOCAL_STORE, "관리 대상 매장", null)
        );

        AdminOverviewResponse overview = adminOperationsService.overview(admin);
        assertThat(overview.totalUsers()).isGreaterThanOrEqualTo(2);
        assertThat(overview.pendingSellers()).isGreaterThanOrEqualTo(1);
        assertThat(adminOperationsService.users(admin))
                .extracting("userId")
                .contains(admin.getId(), seller.getId());
        assertThat(adminOperationsService.sellers(admin))
                .extracting("sellerProfileId")
                .contains(profile.getId());
        assertThat(adminOperationsService.stores(admin))
                .extracting("storeId")
                .contains(store.getId());

        assertThat(adminOperationsService.changeUserStatus(
                admin,
                seller.getId(),
                UserStatus.SUSPENDED
        ).status()).isEqualTo(UserStatus.SUSPENDED);
        assertThat(adminOperationsService.changeSellerVerification(
                admin,
                profile.getId(),
                SellerVerificationStatus.VERIFIED
        ).verificationStatus()).isEqualTo(SellerVerificationStatus.VERIFIED);
        assertThat(adminOperationsService.changeStoreStatus(
                admin,
                store.getId(),
                StoreStatus.SUSPENDED
        ).status()).isEqualTo(StoreStatus.SUSPENDED);
    }

    @Test
    void sellerCannotUseAdminOperations() {
        User seller = createUser(PlatformRole.SELLER, "일반 판매자");

        assertErrorCode(
                () -> adminOperationsService.overview(seller),
                ErrorCode.ACCESS_DENIED
        );
        assertErrorCode(
                () -> adminOperationsService.users(seller),
                ErrorCode.ACCESS_DENIED
        );
    }

    @Test
    void adminCannotSuspendOwnAccount() {
        User admin = createUser(PlatformRole.ADMIN, "자기 보호 관리자");

        assertErrorCode(
                () -> adminOperationsService.changeUserStatus(
                        admin,
                        admin.getId(),
                        UserStatus.SUSPENDED
                ),
                ErrorCode.INVALID_REQUEST
        );
    }

    private User createUser(PlatformRole role, String name) {
        return userRepository.save(
                User.create(
                        UUID.randomUUID() + "@admin.popq.test",
                        name,
                        role
                )
        );
    }

    private void assertErrorCode(Runnable operation, ErrorCode expected) {
        assertThatThrownBy(operation::run)
                .isInstanceOfSatisfying(
                        BusinessException.class,
                        exception -> assertThat(exception.getErrorCode())
                                .isEqualTo(expected)
                );
    }
}
