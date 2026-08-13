package com.example.project_popq.announcement.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.example.project_popq.announcement.domain.Announcement;
import com.example.project_popq.announcement.domain.AnnouncementStatus;
import com.example.project_popq.announcement.dto.ChangeAnnouncementPinRequest;
import com.example.project_popq.announcement.dto.ChangeAnnouncementStatusRequest;
import com.example.project_popq.announcement.repository.AnnouncementRepository;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.notification.service.AnnouncementNotificationService;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class AnnouncementServiceTests {

    private static final Long STORE_ID = 10L;

    private final AnnouncementRepository announcementRepository =
            mock(AnnouncementRepository.class);
    private final StoreRepository storeRepository = mock(StoreRepository.class);
    private final StoreAuthorizationService authorizationService =
            mock(StoreAuthorizationService.class);
    private final AnnouncementNotificationService notificationService =
            mock(AnnouncementNotificationService.class);
    private final AnnouncementService service = new AnnouncementService(
            announcementRepository,
            storeRepository,
            authorizationService,
            notificationService
    );
    private final User user = user();

    @Test
    void pinsThreeAnnouncementsAndRejectsTheFourth() {
        Store store = store(STORE_ID);
        Map<Long, Announcement> announcements = Map.of(
                1L, published(store),
                2L, published(store),
                3L, published(store),
                4L, published(store)
        );
        when(storeRepository.findForUpdateById(STORE_ID))
                .thenReturn(Optional.of(store));
        when(announcementRepository.findForUpdateByIdAndStoreId(
                org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.eq(STORE_ID)
        )).thenAnswer(invocation -> Optional.ofNullable(
                announcements.get(invocation.getArgument(0, Long.class))
        ));
        when(announcementRepository.countByStoreIdAndPinnedTrue(STORE_ID))
                .thenReturn(0L, 1L, 2L, 3L);

        assertThat(service.changePin(
                user, STORE_ID, 1L, new ChangeAnnouncementPinRequest(true)
        ).pinned()).isTrue();
        assertThat(service.changePin(
                user, STORE_ID, 2L, new ChangeAnnouncementPinRequest(true)
        ).pinned()).isTrue();
        assertThat(service.changePin(
                user, STORE_ID, 3L, new ChangeAnnouncementPinRequest(true)
        ).pinned()).isTrue();
        assertThatThrownBy(() -> service.changePin(
                user, STORE_ID, 4L, new ChangeAnnouncementPinRequest(true)
        )).isInstanceOfSatisfying(
                BusinessException.class,
                error -> assertThat(error.getErrorCode())
                        .isEqualTo(ErrorCode.ANNOUNCEMENT_PIN_LIMIT_EXCEEDED)
        );
    }

    @Test
    void eachStoreHasAnIndependentPinLimit() {
        Long otherStoreId = 20L;
        Store firstStore = store(STORE_ID);
        Store secondStore = store(otherStoreId);
        Announcement first = published(firstStore);
        Announcement second = published(secondStore);
        when(storeRepository.findForUpdateById(STORE_ID))
                .thenReturn(Optional.of(firstStore));
        when(storeRepository.findForUpdateById(otherStoreId))
                .thenReturn(Optional.of(secondStore));
        when(announcementRepository.findForUpdateByIdAndStoreId(1L, STORE_ID))
                .thenReturn(Optional.of(first));
        when(announcementRepository.findForUpdateByIdAndStoreId(2L, otherStoreId))
                .thenReturn(Optional.of(second));
        when(announcementRepository.countByStoreIdAndPinnedTrue(STORE_ID))
                .thenReturn(2L);
        when(announcementRepository.countByStoreIdAndPinnedTrue(otherStoreId))
                .thenReturn(2L);

        assertThat(service.changePin(
                user, STORE_ID, 1L, new ChangeAnnouncementPinRequest(true)
        ).pinned()).isTrue();
        assertThat(service.changePin(
                user, otherStoreId, 2L, new ChangeAnnouncementPinRequest(true)
        ).pinned()).isTrue();
    }

    @Test
    void rejectsDraftAndHiddenAnnouncements() {
        Store store = store(STORE_ID);
        Announcement draft = Announcement.create(store, "draft", "content", null);
        Announcement hidden = Announcement.create(store, "hidden", "content", null);
        hidden.changeStatus(AnnouncementStatus.HIDDEN, Instant.now());
        when(storeRepository.findForUpdateById(STORE_ID))
                .thenReturn(Optional.of(store));
        when(announcementRepository.findForUpdateByIdAndStoreId(1L, STORE_ID))
                .thenReturn(Optional.of(draft));
        when(announcementRepository.findForUpdateByIdAndStoreId(2L, STORE_ID))
                .thenReturn(Optional.of(hidden));

        assertPinRequiresPublished(1L);
        assertPinRequiresPublished(2L);
    }

    @Test
    void hidingAPinnedAnnouncementAutomaticallyUnpinsIt() {
        Store store = store(STORE_ID);
        Announcement announcement = published(store);
        announcement.pin();
        when(announcementRepository.findForUpdateByIdAndStoreId(1L, STORE_ID))
                .thenReturn(Optional.of(announcement));

        assertThat(service.changeStatus(
                user,
                STORE_ID,
                1L,
                new ChangeAnnouncementStatusRequest(AnnouncementStatus.HIDDEN)
        ).pinned()).isFalse();
        assertThat(announcement.getStatus()).isEqualTo(AnnouncementStatus.HIDDEN);
    }

    private void assertPinRequiresPublished(Long announcementId) {
        assertThatThrownBy(() -> service.changePin(
                user,
                STORE_ID,
                announcementId,
                new ChangeAnnouncementPinRequest(true)
        )).isInstanceOfSatisfying(
                BusinessException.class,
                error -> assertThat(error.getErrorCode())
                        .isEqualTo(ErrorCode.ANNOUNCEMENT_PIN_REQUIRES_PUBLISHED)
        );
    }

    private Announcement published(Store store) {
        Announcement announcement = Announcement.create(store, "title", "content", null);
        announcement.changeStatus(AnnouncementStatus.PUBLISHED, Instant.now());
        return announcement;
    }

    private Store store(Long id) {
        Store store = mock(Store.class);
        when(store.getId()).thenReturn(id);
        return store;
    }

    private User user() {
        User result = mock(User.class);
        when(result.getId()).thenReturn(100L);
        return result;
    }
}
