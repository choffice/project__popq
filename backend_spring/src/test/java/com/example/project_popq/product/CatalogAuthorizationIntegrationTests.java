package com.example.project_popq.product;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.product.dto.CreateCategoryRequest;
import com.example.project_popq.product.dto.CreateProductRequest;
import com.example.project_popq.product.dto.ProductDetailResponse;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest.OptionGroupRequest;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest.OptionRequest;
import com.example.project_popq.product.dto.UpdateAvailabilityRequest;
import com.example.project_popq.product.service.CatalogService;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class CatalogAuthorizationIntegrationTests {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoreRepository storeRepository;

    @Autowired
    private StoreMemberRepository storeMemberRepository;

    @Autowired
    private CatalogService catalogService;

    @Test
    void sellerCannotModifyProductFromAnotherStore() {
        SellerStore ownerA = createSellerStore(
                "catalog-owner-a@popq.test",
                StoreRole.OWNER
        );
        SellerStore ownerB = createSellerStore(
                "catalog-owner-b@popq.test",
                StoreRole.OWNER
        );
        ProductDetailResponse productA = createProduct(ownerA);

        assertErrorCode(
                () -> catalogService.replaceOptions(
                        ownerB.user(),
                        ownerB.store().getId(),
                        productA.product().productId(),
                        validOptions()
                ),
                ErrorCode.PRODUCT_NOT_FOUND
        );
    }

    @Test
    void staffCannotReplaceProductOptions() {
        SellerStore staffStore = createSellerStore(
                "catalog-staff@popq.test",
                StoreRole.STAFF
        );
        ProductDetailResponse product = createProductAsSystem(staffStore.store());

        assertErrorCode(
                () -> catalogService.replaceOptions(
                        staffStore.user(),
                        staffStore.store().getId(),
                        product.product().productId(),
                        validOptions()
                ),
                ErrorCode.STORE_ACCESS_DENIED
        );
    }

    @Test
    void ownerCanConfigureOptionsAndStaffCanMarkSoldOut() {
        SellerStore ownerStore = createSellerStore(
                "catalog-owner@popq.test",
                StoreRole.OWNER
        );
        ProductDetailResponse product = createProduct(ownerStore);

        ProductDetailResponse configured = catalogService.replaceOptions(
                ownerStore.user(),
                ownerStore.store().getId(),
                product.product().productId(),
                validOptions()
        );
        assertThat(configured.optionGroups()).hasSize(1);
        assertThat(configured.optionGroups().get(0).options()).hasSize(2);
        ProductDetailResponse fetched = catalogService.findSellerProduct(
                ownerStore.user(),
                ownerStore.store().getId(),
                product.product().productId()
        );
        assertThat(fetched.optionGroups()).hasSize(1);
        assertThat(fetched.optionGroups().get(0).options())
                .extracting("name")
                .containsExactly("HOT", "ICE");

        User staff = userRepository.save(
                User.create(
                        "catalog-soldout-staff@popq.test",
                        "품절 담당자",
                        PlatformRole.SELLER
                )
        );
        storeMemberRepository.save(
                StoreMember.create(ownerStore.store(), staff, StoreRole.STAFF)
        );
        ProductDetailResponse soldOut = catalogService.updateAvailability(
                staff,
                ownerStore.store().getId(),
                product.product().productId(),
                new UpdateAvailabilityRequest(true, null, null, true, true)
        );

        assertThat(soldOut.availability().soldOut()).isTrue();
        assertThat(soldOut.product().soldOut()).isTrue();
        assertThat(soldOut.product().availableForQr()).isFalse();
        assertThat(soldOut.product().qrWebEnabled()).isTrue();
        assertThat(soldOut.product().customerAppEnabled()).isTrue();
        assertThat(soldOut.product().salesStartAt()).isNull();
        assertThat(soldOut.product().salesEndAt()).isNull();
    }

    private ProductDetailResponse createProduct(SellerStore fixture) {
        Long categoryId = catalogService.createCategory(
                fixture.user(),
                fixture.store().getId(),
                new CreateCategoryRequest("음료", 0)
        ).categoryId();
        return catalogService.createProduct(
                fixture.user(),
                fixture.store().getId(),
                new CreateProductRequest(
                        categoryId,
                        "아메리카노",
                        "테스트 상품",
                        null,
                        4500
                )
        );
    }

    private ProductDetailResponse createProductAsSystem(Store store) {
        User owner = userRepository.save(
                User.create(
                        "catalog-system-owner-" + store.getId() + "@popq.test",
                        "임시 소유자",
                        PlatformRole.SELLER
                )
        );
        storeMemberRepository.save(
                StoreMember.create(store, owner, StoreRole.OWNER)
        );
        return createProduct(new SellerStore(owner, store));
    }

    private SellerStore createSellerStore(String email, StoreRole role) {
        User user = userRepository.save(
                User.create(email, "카탈로그 판매자", PlatformRole.SELLER)
        );
        Store store = storeRepository.save(
                Store.create(StoreType.LOCAL_STORE, "카탈로그 테스트", null)
        );
        storeMemberRepository.save(StoreMember.create(store, user, role));
        return new SellerStore(user, store);
    }

    private ReplaceProductOptionsRequest validOptions() {
        return new ReplaceProductOptionsRequest(
                List.of(
                        new OptionGroupRequest(
                                "온도",
                                1,
                                1,
                                true,
                                0,
                                List.of(
                                        new OptionRequest("HOT", 0, 0),
                                        new OptionRequest("ICE", 500, 1)
                                )
                        )
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

    private record SellerStore(User user, Store store) {
    }
}
