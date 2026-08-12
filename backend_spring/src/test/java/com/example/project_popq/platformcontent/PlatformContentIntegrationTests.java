package com.example.project_popq.platformcontent;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.ContentStatus;
import com.example.project_popq.platformcontent.dto.FaqRequest;
import com.example.project_popq.platformcontent.dto.PlatformAnnouncementRequest;
import com.example.project_popq.platformcontent.service.PlatformContentService;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class PlatformContentIntegrationTests {

    @Autowired private PlatformContentService service;
    @Autowired private UserRepository userRepository;

    @Test
    void publishedContentIsExposedOnlyToMatchingAudience() {
        User admin = createAdmin();
        Instant now = Instant.now();
        var announcement = service.createAnnouncement(admin, new PlatformAnnouncementRequest.Save(
                AppAudience.CUSTOMER_APP,
                "구매자 공지",
                "구매자 앱에만 노출됩니다.",
                now.minus(1, ChronoUnit.HOURS),
                now.plus(1, ChronoUnit.DAYS)
        ));
        service.changeAnnouncementStatus(
                admin,
                announcement.platformAnnouncementId(),
                new PlatformAnnouncementRequest.ChangeStatus(ContentStatus.PUBLISHED)
        );

        var faq = service.createFaq(admin, new FaqRequest.Save(
                AppAudience.ALL, "계정", "비밀번호는 어떻게 바꾸나요?",
                "계정 설정에서 변경할 수 있습니다.", 1
        ));
        service.changeFaqStatus(
                admin,
                faq.faqId(),
                new FaqRequest.ChangeStatus(ContentStatus.PUBLISHED)
        );

        assertThat(service.publishedAnnouncements(AppAudience.CUSTOMER_APP))
                .extracting("title")
                .contains("구매자 공지");
        assertThat(service.publishedAnnouncements(AppAudience.SELLER_APP))
                .extracting("title")
                .doesNotContain("구매자 공지");
        assertThat(service.publishedFaqs(AppAudience.SELLER_APP))
                .extracting("question")
                .contains("비밀번호는 어떻게 바꾸나요?");
    }

    private User createAdmin() {
        return userRepository.save(User.create(
                UUID.randomUUID() + "@content.test",
                "콘텐츠 관리자",
                PlatformRole.ADMIN
        ));
    }
}
