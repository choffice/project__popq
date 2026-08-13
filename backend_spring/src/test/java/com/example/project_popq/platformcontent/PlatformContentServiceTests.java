package com.example.project_popq.platformcontent;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.example.project_popq.admin.repository.AdminAuditLogRepository;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.ContentStatus;
import com.example.project_popq.platformcontent.domain.PlatformAnnouncement;
import com.example.project_popq.platformcontent.repository.FaqRepository;
import com.example.project_popq.platformcontent.repository.PlatformAnnouncementRepository;
import com.example.project_popq.platformcontent.service.PlatformContentService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class PlatformContentServiceTests {

    private final PlatformAnnouncementRepository announcementRepository =
            mock(PlatformAnnouncementRepository.class);
    private final PlatformContentService service = new PlatformContentService(
            announcementRepository,
            mock(FaqRepository.class),
            mock(AdminAuditLogRepository.class)
    );

    @Test
    void returnsPublishedAnnouncementForRequestedAudience() {
        PlatformAnnouncement announcement = announcement();
        when(announcementRepository.findPublishedById(
                org.mockito.ArgumentMatchers.eq(7L),
                org.mockito.ArgumentMatchers.eq(AppAudience.CUSTOMER_APP),
                any(Instant.class)
        )).thenReturn(Optional.of(announcement));

        var response = service.publishedAnnouncement(
                AppAudience.CUSTOMER_APP,
                7L
        );

        assertThat(response.platformAnnouncementId()).isEqualTo(7L);
        assertThat(response.title()).isEqualTo("서비스 점검 안내");
    }

    @Test
    void hidesAnnouncementWhenItIsUnavailableForRequestedAudience() {
        when(announcementRepository.findPublishedById(
                org.mockito.ArgumentMatchers.eq(7L),
                org.mockito.ArgumentMatchers.eq(AppAudience.SELLER_APP),
                any(Instant.class)
        )).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.publishedAnnouncement(
                AppAudience.SELLER_APP,
                7L
        )).isInstanceOfSatisfying(
                BusinessException.class,
                error -> assertThat(error.getErrorCode())
                        .isEqualTo(ErrorCode.PLATFORM_ANNOUNCEMENT_NOT_FOUND)
        );
    }

    private PlatformAnnouncement announcement() {
        PlatformAnnouncement announcement = mock(PlatformAnnouncement.class);
        User author = mock(User.class);
        Instant now = Instant.parse("2026-08-13T00:00:00Z");
        when(announcement.getId()).thenReturn(7L);
        when(announcement.getAudience()).thenReturn(AppAudience.ALL);
        when(announcement.getTitle()).thenReturn("서비스 점검 안내");
        when(announcement.getContent()).thenReturn("일부 기능이 제한됩니다.");
        when(announcement.getStatus()).thenReturn(ContentStatus.PUBLISHED);
        when(announcement.getPublishStartAt()).thenReturn(now);
        when(announcement.getAuthor()).thenReturn(author);
        when(author.getName()).thenReturn("관리자");
        when(announcement.getCreatedAt()).thenReturn(now);
        when(announcement.getUpdatedAt()).thenReturn(now);
        return announcement;
    }
}
