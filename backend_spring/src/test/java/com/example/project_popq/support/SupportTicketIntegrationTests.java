package com.example.project_popq.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.support.domain.SupportCategory;
import com.example.project_popq.support.domain.SupportRequesterType;
import com.example.project_popq.support.domain.SupportTicketStatus;
import com.example.project_popq.support.dto.SupportTicketRequest;
import com.example.project_popq.support.service.SupportTicketService;
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
class SupportTicketIntegrationTests {

    @Autowired private SupportTicketService service;
    @Autowired private UserRepository userRepository;

    @Test
    void requesterAndAdminCanExchangeMessagesAndCloseTicket() {
        User customer = createUser(PlatformRole.CUSTOMER, "문의 고객");
        User admin = createUser(PlatformRole.ADMIN, "문의 관리자");
        var created = service.create(customer, new SupportTicketRequest.Create(
                SupportRequesterType.CUSTOMER,
                SupportCategory.STORE_VISIBILITY,
                "가게가 안 보여요",
                "검색 결과에 매장이 없습니다."
        ));

        var replied = service.addAdminMessage(
                admin,
                created.ticket().supportTicketId(),
                new SupportTicketRequest.Message("확인 후 안내드리겠습니다.")
        );
        assertThat(replied.messages()).hasSize(2);
        assertThat(replied.ticket().status()).isEqualTo(SupportTicketStatus.WAITING_REQUESTER);

        var closed = service.changeStatus(
                admin,
                created.ticket().supportTicketId(),
                new SupportTicketRequest.ChangeStatus(SupportTicketStatus.CLOSED)
        );
        assertThat(closed.ticket().status()).isEqualTo(SupportTicketStatus.CLOSED);

        assertThatThrownBy(() -> service.addRequesterMessage(
                customer,
                created.ticket().supportTicketId(),
                new SupportTicketRequest.Message("추가 질문")
        )).isInstanceOfSatisfying(
                BusinessException.class,
                exception -> assertThat(exception.getErrorCode())
                        .isEqualTo(ErrorCode.SUPPORT_TICKET_CLOSED)
        );
    }

    @Test
    void requesterCannotReadAnotherUsersTicket() {
        User first = createUser(PlatformRole.CUSTOMER, "첫 고객");
        User second = createUser(PlatformRole.CUSTOMER, "둘째 고객");
        var created = service.create(first, new SupportTicketRequest.Create(
                SupportRequesterType.CUSTOMER,
                SupportCategory.ACCOUNT,
                "계정 문의",
                "로그인 문의입니다."
        ));

        assertThatThrownBy(() -> service.myTicket(second, created.ticket().supportTicketId()))
                .isInstanceOfSatisfying(
                        BusinessException.class,
                        exception -> assertThat(exception.getErrorCode())
                                .isEqualTo(ErrorCode.SUPPORT_TICKET_NOT_FOUND)
                );
    }

    @Test
    void sellerUnreadCountIsClearedWhenTicketIsMarkedAsRead() {
        User seller = createUser(PlatformRole.SELLER, "문의 판매자");
        User admin = createUser(PlatformRole.ADMIN, "문의 관리자");
        var created = service.create(seller, new SupportTicketRequest.Create(
                SupportRequesterType.SELLER,
                SupportCategory.OTHER,
                "앱 문의",
                "알림이 오지 않습니다."
        ));
        Long ticketId = created.ticket().supportTicketId();

        var initialTickets = service.myTickets(seller, 0, 20).content();
        assertThat(initialTickets).hasSize(1);
        assertThat(initialTickets.get(0).unreadMessageCount()).isZero();

        service.addAdminMessage(
                admin,
                ticketId,
                new SupportTicketRequest.Message("알림 설정을 확인해 주세요.")
        );

        assertThat(service.myTicket(seller, ticketId).ticket().unreadMessageCount())
                .isEqualTo(1L);
        var unreadTickets = service.myTickets(seller, 0, 20).content();
        assertThat(unreadTickets).hasSize(1);
        assertThat(unreadTickets.get(0).unreadMessageCount()).isEqualTo(1L);

        var read = service.markRequesterRead(seller, ticketId);
        assertThat(read.ticket().unreadMessageCount()).isZero();
        var readTickets = service.myTickets(seller, 0, 20).content();
        assertThat(readTickets).hasSize(1);
        assertThat(readTickets.get(0).unreadMessageCount()).isZero();

        service.addAdminMessage(
                admin,
                ticketId,
                new SupportTicketRequest.Message("추가 안내드립니다.")
        );

        var nextUnreadTickets = service.myTickets(seller, 0, 20).content();
        assertThat(nextUnreadTickets).hasSize(1);
        assertThat(nextUnreadTickets.get(0).unreadMessageCount()).isEqualTo(1L);
    }

    private User createUser(PlatformRole role, String name) {
        return userRepository.save(User.create(
                UUID.randomUUID() + "@support.test",
                name,
                role
        ));
    }
}
