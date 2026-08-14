package com.example.project_popq.store;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.product.domain.Product;
import com.example.project_popq.product.domain.ProductCategory;
import com.example.project_popq.product.domain.Tag;
import com.example.project_popq.product.domain.TagType;
import com.example.project_popq.product.repository.ProductCategoryRepository;
import com.example.project_popq.product.repository.ProductRepository;
import com.example.project_popq.product.repository.TagRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreTag;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.dto.PublicStoreResponse;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.repository.StoreTagRepository;
import com.example.project_popq.store.service.PublicStoreQueryService;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class PublicStoreKeywordSearchIntegrationTests {

    private static final ZoneId SEOUL_ZONE = ZoneId.of("Asia/Seoul");

    @Autowired private PublicStoreQueryService publicStoreQueryService;
    @Autowired private StoreRepository storeRepository;
    @Autowired private StoreTagRepository storeTagRepository;
    @Autowired private TagRepository tagRepository;
    @Autowired private ProductCategoryRepository productCategoryRepository;
    @Autowired private ProductRepository productRepository;

    @Test
    void existingNameCategoryAddressAndTagSearchesRemainSupported() {
        Store store = saveStore(
                StoreType.LOCAL_STORE,
                "LegacyNameKeyword",
                null,
                "LegacyAddressKeyword",
                "LegacyCategoryKeyword",
                null,
                LocalDate.now(SEOUL_ZONE).minusDays(30)
        );
        Tag tag = tagRepository.save(Tag.create(
                "LegacyTagKeyword",
                TagType.STORE
        ));
        storeTagRepository.save(StoreTag.create(store, tag));

        assertSearchContains("legacynamekeyword", store.getId());
        assertSearchContains("legacycategorykeyword", store.getId());
        assertSearchContains("legacyaddresskeyword", store.getId());
        assertSearchContains("legacytagkeyword", store.getId());

        PublicStoreResponse response = search("LegacyNameKeyword").get(0);
        assertThat(response.eventName()).isNull();
    }

    @Test
    void eventNameSearchReturnsEventNameInPublicResponse() {
        Store eventStore = saveStore(
                StoreType.EVENT_COMMERCE,
                "Event Booth Without Keyword",
                "BusanCoffeeFestivalKeyword",
                "Busan",
                "Festival",
                LocalDate.now(SEOUL_ZONE).plusDays(5),
                LocalDate.now(SEOUL_ZONE).plusDays(10)
        );

        List<PublicStoreResponse> result = search("busancoffeefestivalkeyword");

        assertThat(result).extracting(PublicStoreResponse::storeId)
                .containsExactly(eventStore.getId());
        assertThat(result.get(0).eventName())
                .isEqualTo("BusanCoffeeFestivalKeyword");
    }

    @Test
    void productNameSearchUsesCustomerVisibilityButDoesNotExcludeSoldOut() {
        Instant now = Instant.now();
        Store activeStore = saveLocalStore("VisibleMenuStore");
        saveProduct(activeStore, "UniqueMenuSearch Active One", false,
                true, null, null, false);
        saveProduct(activeStore, "UniqueMenuSearch Active Two", false,
                true, null, null, false);

        Store soldOutStore = saveLocalStore("SoldOutMenuStore");
        saveProduct(soldOutStore, "UniqueMenuSearch Sold Out", true,
                true, null, null, false);

        Store deletedStore = saveLocalStore("DeletedMenuStore");
        saveProduct(deletedStore, "UniqueMenuSearch Deleted", false,
                true, null, null, true);

        Store disabledStore = saveLocalStore("DisabledMenuStore");
        saveProduct(disabledStore, "UniqueMenuSearch Disabled", false,
                false, null, null, false);

        Store futureStore = saveLocalStore("FutureMenuStore");
        saveProduct(futureStore, "UniqueMenuSearch Future", false,
                true, now.plusSeconds(3600), null, false);

        Store endedStore = saveLocalStore("EndedMenuStore");
        saveProduct(endedStore, "UniqueMenuSearch Ended", false,
                true, null, now.minusSeconds(3600), false);

        List<PublicStoreResponse> result = search("uniquemenusearch");

        assertThat(result).extracting(PublicStoreResponse::storeId)
                .containsExactlyInAnyOrder(
                        activeStore.getId(),
                        soldOutStore.getId()
                );
    }

    @Test
    void expiredEventsAreHiddenFromListAndDetailWithoutAffectingLocalStores() {
        LocalDate today = LocalDate.now(SEOUL_ZONE);
        Store endingToday = saveStore(
                StoreType.EVENT_COMMERCE,
                "EventPolicyKeyword Today",
                "EventPolicyKeyword",
                "Busan",
                "Festival",
                today.minusDays(3),
                today
        );
        Store futureEvent = saveStore(
                StoreType.EVENT_COMMERCE,
                "EventPolicyKeyword Future",
                "EventPolicyKeyword",
                "Busan",
                "Festival",
                today.plusDays(5),
                today.plusDays(10)
        );
        Store expiredEvent = saveStore(
                StoreType.EVENT_COMMERCE,
                "EventPolicyKeyword Expired",
                "EventPolicyKeyword",
                "Busan",
                "Festival",
                today.minusDays(3),
                today.minusDays(1)
        );
        Store localWithPastEnd = saveStore(
                StoreType.LOCAL_STORE,
                "EventPolicyKeyword Local",
                null,
                "Busan",
                "Cafe",
                today.minusDays(30),
                today.minusDays(1)
        );

        List<PublicStoreResponse> result = search("eventpolicykeyword");

        assertThat(result).extracting(PublicStoreResponse::storeId)
                .containsExactlyInAnyOrder(
                        endingToday.getId(),
                        futureEvent.getId(),
                        localWithPastEnd.getId()
                )
                .doesNotContain(expiredEvent.getId());
        assertThat(publicStoreQueryService.findDetail(endingToday.getId()).storeId())
                .isEqualTo(endingToday.getId());
        assertThatThrownBy(() -> publicStoreQueryService.findDetail(
                expiredEvent.getId()
        )).isInstanceOf(BusinessException.class);
    }

    private Store saveLocalStore(String name) {
        return saveStore(
                StoreType.LOCAL_STORE,
                name,
                null,
                "Busan",
                "Cafe",
                null,
                LocalDate.now(SEOUL_ZONE).minusDays(1)
        );
    }

    private Store saveStore(
            StoreType storeType,
            String name,
            String eventName,
            String address,
            String category,
            LocalDate operationStartDate,
            LocalDate operationEndDate
    ) {
        Store store = Store.create(storeType, name, null);
        store.updateEventName(eventName);
        store.updateDiscoveryProfile(address, null, null);
        store.updateBusinessProfile(category, null, null, null);
        store.updateOperationPeriod(operationStartDate, operationEndDate);
        return storeRepository.save(store);
    }

    private void saveProduct(
            Store store,
            String name,
            boolean soldOut,
            boolean customerAppEnabled,
            Instant salesStartAt,
            Instant salesEndAt,
            boolean deleted
    ) {
        ProductCategory category = productCategoryRepository.save(
                ProductCategory.create(store, name + " Category", 0)
        );
        Product product = Product.create(
                store,
                category,
                name,
                null,
                null,
                1000L
        );
        product.getAvailability().update(
                soldOut,
                salesStartAt,
                salesEndAt,
                true,
                customerAppEnabled
        );
        if (deleted) {
            product.delete();
        }
        productRepository.save(product);
    }

    private void assertSearchContains(String query, Long storeId) {
        assertThat(search(query)).extracting(PublicStoreResponse::storeId)
                .contains(storeId);
    }

    private List<PublicStoreResponse> search(String query) {
        return publicStoreQueryService.search(
                query,
                null,
                null,
                null,
                null
        );
    }
}
