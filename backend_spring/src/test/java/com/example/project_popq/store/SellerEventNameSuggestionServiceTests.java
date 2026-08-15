package com.example.project_popq.store;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.dto.NearbyEventNameSuggestionResponse;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.service.SellerEventNameSuggestionService;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class SellerEventNameSuggestionServiceTests {

    private static final BigDecimal CENTER_LATITUDE = new BigDecimal("35.157778");
    private static final BigDecimal CENTER_LONGITUDE = new BigDecimal("129.059167");
    private static final double RADIUS_KM = 10.0;

    @Mock
    private StoreRepository storeRepository;

    @Test
    void futureAndTodayEndingEventsAreSuggestedButExpiredEventIsExcluded() {
        LocalDate today = today();
        Store futureEvent = eventStore(
                "미래 행사", today.plusDays(5), today.plusDays(10),
                CENTER_LATITUDE, CENTER_LONGITUDE
        );
        Store todayEndingEvent = eventStore(
                "오늘 종료 행사", today.minusDays(2), today,
                CENTER_LATITUDE, CENTER_LONGITUDE
        );
        Store expiredEvent = eventStore(
                "지난 행사", today.minusDays(5), today.minusDays(1),
                CENTER_LATITUDE, CENTER_LONGITUDE
        );
        mockCandidates(futureEvent, todayEndingEvent, expiredEvent);

        List<NearbyEventNameSuggestionResponse> result = findNearby();

        assertThat(result).extracting(NearbyEventNameSuggestionResponse::eventName)
                .containsExactly("미래 행사", "오늘 종료 행사");
    }

    @Test
    void duplicateEventNamesAreGroupedAndAnyValidStoreKeepsSuggestionActive() {
        LocalDate today = today();
        mockCandidates(
                eventStore("부산 커피 페스타", today.minusDays(5), today.minusDays(2),
                        CENTER_LATITUDE, CENTER_LONGITUDE),
                eventStore("부산 커피 페스타", today.minusDays(4), today.minusDays(1),
                        CENTER_LATITUDE, CENTER_LONGITUDE),
                eventStore("부산 커피 페스타", today.plusDays(1), today.plusDays(3),
                        CENTER_LATITUDE, CENTER_LONGITUDE)
        );

        List<NearbyEventNameSuggestionResponse> result = findNearby();

        assertThat(result).containsExactly(
                new NearbyEventNameSuggestionResponse("부산 커피 페스타", 1L)
        );
    }

    @Test
    void eventNameIsExcludedWhenAllStoresUsingItAreExpired() {
        LocalDate today = today();
        mockCandidates(
                eventStore("종료된 행사", today.minusDays(5), today.minusDays(2),
                        CENTER_LATITUDE, CENTER_LONGITUDE),
                eventStore("종료된 행사", today.minusDays(4), today.minusDays(1),
                        CENTER_LATITUDE, CENTER_LONGITUDE)
        );

        assertThat(findNearby()).isEmpty();
    }

    @Test
    void localAndClosedStoresAreNotSuggestionCandidates() {
        LocalDate today = today();
        Store localStore = Store.create(StoreType.LOCAL_STORE, "로컬", null);
        localStore.updateEventName("잘못 남은 행사명");
        localStore.updateOperationPeriod(today, today.plusDays(1));
        localStore.updateDiscoveryProfile(
                null, CENTER_LATITUDE, CENTER_LONGITUDE
        );
        Store closedStore = eventStore(
                "폐업 행사", today, today.plusDays(1),
                CENTER_LATITUDE, CENTER_LONGITUDE
        );
        closedStore.changeStatus(StoreStatus.CLOSED);
        mockCandidates(localStore, closedStore);

        assertThat(findNearby()).isEmpty();
    }

    @Test
    void eventOutsideCustomerDiscoveryRadiusIsExcluded() {
        LocalDate today = today();
        mockCandidates(eventStore(
                "범위 밖 행사", today, today.plusDays(1),
                new BigDecimal("36.157778"), CENTER_LONGITUDE
        ));

        assertThat(findNearby()).isEmpty();
    }

    @Test
    void threeNearbyActiveStoresWithSameNameReturnOneSuggestionWithCountThree() {
        LocalDate today = today();
        mockCandidates(
                eventStore("공동 행사", today, today.plusDays(1),
                        CENTER_LATITUDE, CENTER_LONGITUDE),
                eventStore("공동 행사", today, today.plusDays(2),
                        CENTER_LATITUDE, CENTER_LONGITUDE),
                eventStore("공동 행사", today.plusDays(1), today.plusDays(3),
                        CENTER_LATITUDE, CENTER_LONGITUDE)
        );

        assertThat(findNearby()).containsExactly(
                new NearbyEventNameSuggestionResponse("공동 행사", 3L)
        );
    }

    private List<NearbyEventNameSuggestionResponse> findNearby() {
        return new SellerEventNameSuggestionService(storeRepository).findNearby(
                CENTER_LATITUDE, CENTER_LONGITUDE, RADIUS_KM
        );
    }

    private void mockCandidates(Store... stores) {
        when(storeRepository.findEventNameSuggestionCandidates(any(LocalDate.class)))
                .thenReturn(List.of(stores));
    }

    private Store eventStore(
            String eventName,
            LocalDate start,
            LocalDate end,
            BigDecimal latitude,
            BigDecimal longitude
    ) {
        Store store = Store.create(StoreType.EVENT_COMMERCE, eventName, null);
        store.updateEventName(eventName);
        store.updateOperationPeriod(start, end);
        store.updateDiscoveryProfile(null, latitude, longitude);
        return store;
    }

    private LocalDate today() {
        return LocalDate.now(ZoneId.of("Asia/Seoul"));
    }
}
