package com.example.project_popq.support;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.project_popq.support.domain.SupportInquiryCategory;
import com.example.project_popq.support.domain.SupportInquiryStatus;
import com.example.project_popq.support.dto.CreateSupportInquiryRequest;
import com.example.project_popq.support.dto.SendSupportMessageRequest;
import com.example.project_popq.support.service.AdminSupportInquiryService;
import com.example.project_popq.support.service.CustomerSupportInquiryService;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
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
class SupportInquiryIntegrationTests {

    @Autowired private CustomerSupportInquiryService customerService;
    @Autowired private AdminSupportInquiryService adminService;
    @Autowired private UserRepository userRepository;

    @Test
    void customerInquiryIsVisibleAndAnswerableFromAdminManagement() {
        User customer = createUser(PlatformRole.CUSTOMER, "구매자 문의 고객");
        User admin = createUser(PlatformRole.ADMIN, "문의 관리자");

        var created = customerService.createInquiry(
                customer,
                new CreateSupportInquiryRequest(
                        SupportInquiryCategory.APP,
                        "앱 이용 문의",
                        "공지 화면을 확인하고 싶습니다."
                )
        );

        var adminList = adminService.getInquiries(admin, SupportInquiryStatus.RECEIVED);
        assertThat(adminList)
                .extracting("supportInquiryId")
                .contains(created.inquiry().supportInquiryId());
        assertThat(adminList.get(0).unreadMessageCount()).isEqualTo(1);

        var opened = adminService.getInquiry(admin, created.inquiry().supportInquiryId());
        assertThat(opened.inquiry().status()).isEqualTo(SupportInquiryStatus.IN_PROGRESS);

        var answered = adminService.sendAnswer(
                admin,
                created.inquiry().supportInquiryId(),
                new SendSupportMessageRequest("확인 방법을 안내드립니다.")
        );
        assertThat(answered.inquiry().status()).isEqualTo(SupportInquiryStatus.ANSWERED);
        assertThat(answered.messages()).hasSize(2);

        var customerDetail = customerService.getMyInquiry(
                customer,
                created.inquiry().supportInquiryId()
        );
        assertThat(customerDetail.messages())
                .extracting("content")
                .contains("확인 방법을 안내드립니다.");
    }

    private User createUser(PlatformRole role, String name) {
        return userRepository.save(User.create(
                UUID.randomUUID() + "@support-inquiry.test",
                name,
                role
        ));
    }
}
