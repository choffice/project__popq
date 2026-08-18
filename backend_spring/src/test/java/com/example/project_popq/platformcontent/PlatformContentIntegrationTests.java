package com.example.project_popq.platformcontent;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.common.error.BusinessException;
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
        assertThat(service.publishedAnnouncement(
                AppAudience.CUSTOMER_APP,
                announcement.platformAnnouncementId()
        ).title()).isEqualTo("구매자 공지");
        assertThatThrownBy(() -> service.publishedAnnouncement(
                AppAudience.SELLER_APP,
                announcement.platformAnnouncementId()
        )).isInstanceOf(BusinessException.class);
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

    @Test
    void publishedFaqsExposeOnlyPublishedAndMatchingAudienceInDisplayOrder() {
        User admin = createAdmin();

        var allFaq = service.createFaq(admin, new FaqRequest.Save(
            AppAudience.ALL,
            "통합 테스트",
            "FAQ-ALL",
            "모든 앱에 표시됩니다.",
            20
        ));
        service.changeFaqStatus(
            admin,
            allFaq.faqId(),
            new FaqRequest.ChangeStatus(ContentStatus.PUBLISHED)
        );

        var customerFaq = service.createFaq(admin, new FaqRequest.Save(
            AppAudience.CUSTOMER_APP,
            "통합 테스트",
            "FAQ-CUSTOMER",
            "고객 앱에만 표시됩니다.",
            10
        ));
        service.changeFaqStatus(
            admin,
            customerFaq.faqId(),
            new FaqRequest.ChangeStatus(ContentStatus.PUBLISHED)
        );

        var sellerFaq = service.createFaq(admin, new FaqRequest.Save(
            AppAudience.SELLER_APP,
            "통합 테스트",
            "FAQ-SELLER",
            "판매자 앱에만 표시됩니다.",
            5
        ));
        service.changeFaqStatus(
            admin,
            sellerFaq.faqId(),
            new FaqRequest.ChangeStatus(ContentStatus.PUBLISHED)
        );

        service.createFaq(admin, new FaqRequest.Save(
            AppAudience.CUSTOMER_APP,
            "통합 테스트",
            "FAQ-DRAFT",
            "초안은 표시되면 안 됩니다.",
            1
        ));

        var hiddenFaq = service.createFaq(admin, new FaqRequest.Save(
            AppAudience.CUSTOMER_APP,
            "통합 테스트",
            "FAQ-HIDDEN",
            "숨김 FAQ는 표시되면 안 됩니다.",
            2
        ));
        service.changeFaqStatus(
            admin,
            hiddenFaq.faqId(),
            new FaqRequest.ChangeStatus(ContentStatus.HIDDEN)
        );

        var customerFaqs = service.publishedFaqs(AppAudience.CUSTOMER_APP)
            .stream()
            .filter(faq -> faq.category().equals("통합 테스트"))
            .toList();

        assertThat(customerFaqs)
            .extracting("question")
            .containsExactly(
                "FAQ-CUSTOMER",
                "FAQ-ALL"
            );

        var sellerFaqs = service.publishedFaqs(AppAudience.SELLER_APP)
            .stream()
            .filter(faq -> faq.category().equals("통합 테스트"))
            .toList();

        assertThat(sellerFaqs)
            .extracting("question")
            .containsExactly(
                "FAQ-SELLER",
                "FAQ-ALL"
            );

        assertThat(customerFaqs)
            .extracting("status")
            .containsOnly(ContentStatus.PUBLISHED);

        assertThat(sellerFaqs)
            .extracting("status")
            .containsOnly(ContentStatus.PUBLISHED);

        assertThatThrownBy(
            () -> service.publishedFaqs(AppAudience.ALL)
        )
            .isInstanceOf(BusinessException.class)
            .hasMessageContaining("조회할 앱을 선택해 주세요.");
    }
}
