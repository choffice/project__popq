package com.example.project_popq.store;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class StoreAuthorizationServiceIntegrationTests {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoreRepository storeRepository;

    @Autowired
    private StoreMemberRepository storeMemberRepository;

    @Autowired
    private StoreAuthorizationService storeAuthorizationService;

    @Test
    void ownerCanAccessOwnerOrManagerOperation() {
        User owner = saveUser("owner-auth@popq.test");
        Store store = storeRepository.save(
                Store.create(StoreType.LOCAL_STORE, "권한 테스트", null)
        );
        storeMemberRepository.save(
                StoreMember.create(store, owner, StoreRole.OWNER)
        );

        StoreMember authorized = storeAuthorizationService.requireAnyRole(
                owner.getId(),
                store.getId(),
                StoreRole.OWNER,
                StoreRole.MANAGER
        );

        assertThat(authorized.getRole()).isEqualTo(StoreRole.OWNER);
    }

    @Test
    void memberWithoutRequiredRoleIsRejected() {
        User staff = saveUser("staff-auth@popq.test");
        Store store = storeRepository.save(
                Store.create(StoreType.EVENT_COMMERCE, "행사 권한 테스트", null)
        );
        storeMemberRepository.save(
                StoreMember.create(store, staff, StoreRole.STAFF)
        );

        assertStoreAccessDenied(() -> storeAuthorizationService.requireAnyRole(
                staff.getId(),
                store.getId(),
                StoreRole.OWNER,
                StoreRole.MANAGER
        ));
    }

    @Test
    void userFromAnotherStoreIsRejected() {
        User outsider = saveUser("outsider-auth@popq.test");
        Store store = storeRepository.save(
                Store.create(StoreType.LOCAL_STORE, "타 스토어 테스트", null)
        );

        assertStoreAccessDenied(() -> storeAuthorizationService.requireAnyRole(
                outsider.getId(),
                store.getId(),
                StoreRole.OWNER
        ));
    }

    private User saveUser(String email) {
        return userRepository.save(
                User.create(email, "권한 테스트 사용자", PlatformRole.SELLER)
        );
    }

    private void assertStoreAccessDenied(Runnable operation) {
        assertThatThrownBy(operation::run)
                .isInstanceOfSatisfying(
                        BusinessException.class,
                        exception -> assertThat(exception.getErrorCode())
                                .isEqualTo(ErrorCode.STORE_ACCESS_DENIED)
                );
    }
}

