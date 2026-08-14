package com.example.project_popq.store;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.nullable;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.engagement.repository.ReviewRepository;
import com.example.project_popq.inquiry.repository.OrderMessageRepository;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.product.repository.TagRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.dto.CreateStoreRequest;
import com.example.project_popq.store.dto.UpdateStoreRequest;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.repository.StoreTableRepository;
import com.example.project_popq.store.repository.StoreTagRepository;
import com.example.project_popq.store.service.StoreApplicationService;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.store.service.StoreScheduleService;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class StoreApplicationServiceEventInfoTests {

    @Mock private StoreRepository storeRepository;
    @Mock private StoreMemberRepository storeMemberRepository;
    @Mock private StoreTableRepository storeTableRepository;
    @Mock private StoreTagRepository storeTagRepository;
    @Mock private TagRepository tagRepository;
    @Mock private StoreAuthorizationService storeAuthorizationService;
    @Mock private OrderRepository orderRepository;
    @Mock private ReviewRepository reviewRepository;
    @Mock private OrderMessageRepository orderMessageRepository;
    @Mock private StoreScheduleService storeScheduleService;
    @Mock private User user;
    @Mock private StoreMember member;

    private StoreApplicationService service;

    @BeforeEach
    void setUp() {
        service = new StoreApplicationService(
                storeRepository,
                storeMemberRepository,
                storeTableRepository,
                storeTagRepository,
                tagRepository,
                storeAuthorizationService,
                orderRepository,
                reviewRepository,
                orderMessageRepository,
                storeScheduleService
        );
    }

    @Test
    void newLocalStoreDefaultsMissingStartDateToTodayInSeoul() {
        Store created = create(localRequest(null, null));

        assertThat(created.getOperationStartDate())
                .isEqualTo(LocalDate.now(ZoneId.of("Asia/Seoul")));
        assertThat(created.getEventName()).isNull();
    }

    @Test
    void newLocalStoreKeepsProvidedOperationPeriod() {
        LocalDate start = LocalDate.of(2026, 9, 1);
        LocalDate end = LocalDate.of(2026, 9, 30);

        Store created = create(localRequest(start, end));

        assertThat(created.getOperationStartDate()).isEqualTo(start);
        assertThat(created.getOperationEndDate()).isEqualTo(end);
    }

    @Test
    void newLocalStoreRejectsEndBeforeStart() {
        allowCreate();
        assertThatThrownBy(() -> service.create(
                user,
                localRequest(LocalDate.of(2026, 9, 2), LocalDate.of(2026, 9, 1))
        )).isInstanceOf(BusinessException.class);
    }

    @Test
    void newEventStoreRejectsMissingEventName() {
        allowCreate();
        assertThatThrownBy(() -> service.create(
                user,
                eventRequest(null, LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 2))
        )).isInstanceOf(BusinessException.class);
    }

    @Test
    void newEventStoreRejectsWhitespaceEventName() {
        allowCreate();
        assertThatThrownBy(() -> service.create(
                user,
                eventRequest("   ", LocalDate.of(2026, 9, 1), LocalDate.of(2026, 9, 2))
        )).isInstanceOf(BusinessException.class);
    }

    @Test
    void newEventStoreRejectsMissingStartDate() {
        allowCreate();
        assertThatThrownBy(() -> service.create(
                user,
                eventRequest("가을 마켓", null, LocalDate.of(2026, 9, 2))
        )).isInstanceOf(BusinessException.class);
    }

    @Test
    void newEventStoreRejectsMissingEndDate() {
        allowCreate();
        assertThatThrownBy(() -> service.create(
                user,
                eventRequest("가을 마켓", LocalDate.of(2026, 9, 1), null)
        )).isInstanceOf(BusinessException.class);
    }

    @Test
    void newEventStoreAcceptsCompleteEventInformation() {
        LocalDate start = LocalDate.of(2026, 9, 1);
        LocalDate end = LocalDate.of(2026, 9, 2);

        Store created = create(eventRequest("  가을 마켓  ", start, end));

        assertThat(created.getEventName()).isEqualTo("가을 마켓");
        assertThat(created.getOperationStartDate()).isEqualTo(start);
        assertThat(created.getOperationEndDate()).isEqualTo(end);
    }

    @Test
    void newEventStoreRejectsEndBeforeStart() {
        allowCreate();
        assertThatThrownBy(() -> service.create(
                user,
                eventRequest(
                        "가을 마켓",
                        LocalDate.of(2026, 9, 2),
                        LocalDate.of(2026, 9, 1)
                )
        )).isInstanceOf(BusinessException.class);
    }

    @Test
    void changingLocalStoreToEventRejectsIncompleteEventInformation() {
        Store store = Store.create(StoreType.LOCAL_STORE, "동네 매장", null);
        prepareUpdate(store);

        assertThatThrownBy(() -> service.update(
                user,
                1L,
                updateRequest(StoreType.EVENT_COMMERCE, null, null, null)
        )).isInstanceOf(BusinessException.class);
        assertThat(store.getStoreType()).isEqualTo(StoreType.LOCAL_STORE);
    }

    @Test
    void changingEventStoreToLocalClearsEventNameButKeepsOperationPeriod() {
        Store store = Store.create(StoreType.EVENT_COMMERCE, "행사 매장", null);
        store.updateEventName("가을 마켓");
        LocalDate start = LocalDate.of(2026, 9, 1);
        LocalDate end = LocalDate.of(2026, 9, 2);
        store.updateOperationPeriod(start, end);
        prepareUpdate(store);
        allowUpdateResponse();

        service.update(
                user,
                1L,
                updateRequest(StoreType.LOCAL_STORE, null, null, null)
        );

        assertThat(store.getStoreType()).isEqualTo(StoreType.LOCAL_STORE);
        assertThat(store.getEventName()).isNull();
        assertThat(store.getOperationStartDate()).isEqualTo(start);
        assertThat(store.getOperationEndDate()).isEqualTo(end);
    }

    @Test
    void updatingLegacyLocalStoreDoesNotInventOperationStartDate() {
        Store store = Store.create(StoreType.LOCAL_STORE, "레거시 매장", null);
        prepareUpdate(store);
        allowUpdateResponse();

        service.update(
                user,
                1L,
                updateRequest(null, null, null, null)
        );

        assertThat(store.getOperationStartDate()).isNull();
        assertThat(store.getOperationEndDate()).isNull();
    }

    @Test
    void localStoreCanExplicitlyClearExistingOperationEndDate() {
        Store store = Store.create(StoreType.LOCAL_STORE, "기간제 매장", null);
        LocalDate start = LocalDate.of(2026, 8, 14);
        store.updateOperationPeriod(start, LocalDate.of(2026, 12, 31));
        prepareUpdate(store);
        allowUpdateResponse();

        service.update(
                user,
                1L,
                updateRequest(null, null, null, null, true)
        );

        assertThat(store.getOperationStartDate()).isEqualTo(start);
        assertThat(store.getOperationEndDate()).isNull();
    }

    @Test
    void localStorePartialUpdatePreservesExistingOperationPeriod() {
        Store store = Store.create(StoreType.LOCAL_STORE, "기간제 매장", null);
        LocalDate start = LocalDate.of(2026, 8, 14);
        LocalDate end = LocalDate.of(2026, 12, 31);
        store.updateOperationPeriod(start, end);
        prepareUpdate(store);
        allowUpdateResponse();

        service.update(
                user,
                1L,
                updateRequest(null, null, null, null)
        );

        assertThat(store.getOperationStartDate()).isEqualTo(start);
        assertThat(store.getOperationEndDate()).isEqualTo(end);
    }

    @Test
    void eventStoreRejectsExplicitOperationEndDateClear() {
        Store store = Store.create(StoreType.EVENT_COMMERCE, "행사 매장", null);
        store.updateEventName("가을 마켓");
        store.updateOperationPeriod(
                LocalDate.of(2026, 9, 1),
                LocalDate.of(2026, 9, 2)
        );
        prepareUpdate(store);

        assertThatThrownBy(() -> service.update(
                user,
                1L,
                updateRequest(null, null, null, null, true)
        )).isInstanceOf(BusinessException.class);
        assertThat(store.getOperationEndDate()).isEqualTo(LocalDate.of(2026, 9, 2));
    }

    private Store create(CreateStoreRequest request) {
        allowCreate();
        when(storeMemberRepository.findMaxDisplayOrderByUserId(nullable(Long.class)))
                .thenReturn(0);
        service.create(user, request);
        ArgumentCaptor<Store> captor = ArgumentCaptor.forClass(Store.class);
        verify(storeRepository).save(captor.capture());
        return captor.getValue();
    }

    private void allowCreate() {
        when(user.hasRole(PlatformRole.SELLER)).thenReturn(true);
    }

    private void prepareUpdate(Store store) {
        when(member.getStore()).thenReturn(store);
        when(storeAuthorizationService.requireAnyRole(
                nullable(Long.class),
                org.mockito.ArgumentMatchers.eq(1L),
                org.mockito.ArgumentMatchers.any(StoreRole[].class)
        )).thenReturn(member);
    }

    private void allowUpdateResponse() {
        when(member.getRole()).thenReturn(StoreRole.OWNER);
        when(storeTagRepository.findAllByStoreId(nullable(Long.class)))
                .thenReturn(List.of());
    }

    private CreateStoreRequest localRequest(LocalDate start, LocalDate end) {
        return createRequest(StoreType.LOCAL_STORE, "무시할 행사명", start, end);
    }

    private CreateStoreRequest eventRequest(
            String eventName,
            LocalDate start,
            LocalDate end
    ) {
        return createRequest(StoreType.EVENT_COMMERCE, eventName, start, end);
    }

    private CreateStoreRequest createRequest(
            StoreType storeType,
            String eventName,
            LocalDate start,
            LocalDate end
    ) {
        return new CreateStoreRequest(
                storeType, eventName, "매장", null, null, null, null, null,
                null, null, null, null, null, start, end, null,
                null, null, null, null, null
        );
    }

    private UpdateStoreRequest updateRequest(
            StoreType storeType,
            String eventName,
            LocalDate start,
            LocalDate end
    ) {
        return updateRequest(storeType, eventName, start, end, null);
    }

    private UpdateStoreRequest updateRequest(
            StoreType storeType,
            String eventName,
            LocalDate start,
            LocalDate end,
            Boolean clearOperationEndDate
    ) {
        return new UpdateStoreRequest(
                storeType, eventName, "매장", null, null, null, null, null,
                null, null, null, null, null, start, end, clearOperationEndDate, null,
                null, null, null, null, null
        );
    }
}
