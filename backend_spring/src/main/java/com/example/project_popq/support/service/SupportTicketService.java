package com.example.project_popq.support.service;

import com.example.project_popq.admin.domain.AdminAuditLog;
import com.example.project_popq.admin.repository.AdminAuditLogRepository;
import com.example.project_popq.common.api.PageResponse;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.realtime.support.SupportTicketDomainEventPublisher;
import com.example.project_popq.realtime.support.SupportTicketRealtimeEventType;
import com.example.project_popq.support.domain.SupportCategory;
import com.example.project_popq.support.domain.SupportMessage;
import com.example.project_popq.support.domain.SupportRequesterType;
import com.example.project_popq.support.domain.SupportSenderType;
import com.example.project_popq.support.domain.SupportTicket;
import com.example.project_popq.support.domain.SupportTicketStatus;
import com.example.project_popq.support.dto.SupportMessageResponse;
import com.example.project_popq.support.dto.SupportTicketDetailResponse;
import com.example.project_popq.support.dto.SupportTicketRequest;
import com.example.project_popq.support.dto.SupportTicketSummaryResponse;
import com.example.project_popq.support.repository.SupportMessageRepository;
import com.example.project_popq.support.repository.SupportTicketRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SupportTicketService {

    private final SupportTicketRepository ticketRepository;
    private final SupportMessageRepository messageRepository;
    private final AdminAuditLogRepository auditLogRepository;
    private final SupportTicketDomainEventPublisher realtimeEventPublisher;

    @Transactional
    public SupportTicketDetailResponse create(
            User requester,
            SupportTicketRequest.Create request
    ) {
        requireRequesterRole(requester, request.requesterType());
        Instant now = Instant.now();
        SupportTicket ticket = ticketRepository.save(SupportTicket.create(
                requester,
                request.requesterType(),
                request.category(),
                request.subject(),
                now
        ));
        SupportMessage message = messageRepository.save(SupportMessage.create(
                ticket, requester, SupportSenderType.REQUESTER, request.content()
        ));
        ticket.messageAdded(SupportSenderType.REQUESTER, now);
        realtimeEventPublisher.publish(
                ticket,
                SupportTicketRealtimeEventType.TICKET_CREATED,
                SupportSenderType.REQUESTER,
                now
        );
        return SupportTicketDetailResponse.of(
                ticket,
                java.util.List.of(SupportMessageResponse.from(message))
        );
    }

    @Transactional(readOnly = true)
    public PageResponse<SupportTicketSummaryResponse> myTickets(
            User requester,
            int page,
            int size
    ) {
        Specification<SupportTicket> specification = (root, ignored, builder) ->
                builder.equal(root.get("requester").get("id"), requester.getId());
        var ticketPage = ticketRepository.findAll(
                specification,
                pageRequest(page, size)
        );
        var ticketIds = ticketPage.getContent()
                .stream()
                .map(SupportTicket::getId)
                .toList();
        Map<Long, SupportMessageRepository.TicketUnreadCount> unreadCounts =
                ticketIds.isEmpty()
                        ? Map.of()
                        : messageRepository.countUnreadByTickets(
                                        ticketIds,
                                        SupportSenderType.ADMIN
                                )
                                .stream()
                                .collect(Collectors.toMap(
                                        SupportMessageRepository.TicketUnreadCount::getTicketId,
                                        Function.identity()
                                ));

        return PageResponse.from(
                ticketPage.map(ticket -> SupportTicketSummaryResponse.from(
                        ticket,
                        unreadCounts.containsKey(ticket.getId())
                                ? unreadCounts.get(ticket.getId()).getUnreadMessageCount()
                                : 0L
                ))
        );
    }

    @Transactional(readOnly = true)
    public SupportTicketDetailResponse myTicket(User requester, Long ticketId) {
        SupportTicket ticket = ticketRepository.findByIdAndRequesterId(
                ticketId,
                requester.getId()
        ).orElseThrow(() -> new BusinessException(ErrorCode.SUPPORT_TICKET_NOT_FOUND));
        return requesterDetail(ticket);
    }

    @Transactional
    public SupportTicketDetailResponse addRequesterMessage(
            User requester,
            Long ticketId,
            SupportTicketRequest.Message request
    ) {
        SupportTicket ticket = ticketRepository.findByIdAndRequesterId(
                ticketId,
                requester.getId()
        ).orElseThrow(() -> new BusinessException(ErrorCode.SUPPORT_TICKET_NOT_FOUND));
        requireOpen(ticket);
        messageRepository.save(SupportMessage.create(
                ticket, requester, SupportSenderType.REQUESTER, request.content()
        ));
        Instant now = Instant.now();
        ticket.messageAdded(SupportSenderType.REQUESTER, now);
        realtimeEventPublisher.publish(
                ticket,
                SupportTicketRealtimeEventType.MESSAGE_ADDED,
                SupportSenderType.REQUESTER,
                now
        );
        return requesterDetail(ticket);
    }

    @Transactional
    public SupportTicketDetailResponse markRequesterRead(
            User requester,
            Long ticketId
    ) {
        SupportTicket ticket = ticketRepository.findByIdAndRequesterId(
                ticketId,
                requester.getId()
        ).orElseThrow(() -> new BusinessException(ErrorCode.SUPPORT_TICKET_NOT_FOUND));
        ticket.markRequesterRead(Instant.now());
        return requesterDetail(ticket);
    }

    @Transactional(readOnly = true)
    public PageResponse<SupportTicketSummaryResponse> adminTickets(
            User admin,
            int page,
            int size,
            String query,
            SupportRequesterType requesterType,
            SupportCategory category,
            SupportTicketStatus status
    ) {
        requireAdmin(admin);
        String search = normalize(query);
        Specification<SupportTicket> specification = (root, ignored, builder) -> {
            var predicate = builder.conjunction();
            if (search != null) {
                String pattern = "%" + search.toLowerCase() + "%";
                predicate = builder.and(predicate, builder.or(
                        builder.like(builder.lower(root.get("subject")), pattern),
                        builder.like(builder.lower(root.get("requester").get("name")), pattern),
                        builder.like(
                                builder.lower(builder.coalesce(root.get("requester").get("email"), "")),
                                pattern
                        )
                ));
            }
            if (requesterType != null) {
                predicate = builder.and(
                        predicate,
                        builder.equal(root.get("requesterType"), requesterType)
                );
            }
            if (category != null) {
                predicate = builder.and(predicate, builder.equal(root.get("category"), category));
            }
            if (status != null) {
                predicate = builder.and(predicate, builder.equal(root.get("status"), status));
            }
            return predicate;
        };
        return PageResponse.from(
                ticketRepository.findAll(specification, pageRequest(page, size))
                        .map(SupportTicketSummaryResponse::from)
        );
    }

    @Transactional(readOnly = true)
    public SupportTicketDetailResponse adminTicket(User admin, Long ticketId) {
        requireAdmin(admin);
        return detail(findTicket(ticketId));
    }

    @Transactional
    public SupportTicketDetailResponse addAdminMessage(
            User admin,
            Long ticketId,
            SupportTicketRequest.Message request
    ) {
        requireAdmin(admin);
        SupportTicket ticket = findTicket(ticketId);
        requireOpen(ticket);
        messageRepository.save(SupportMessage.create(
                ticket, admin, SupportSenderType.ADMIN, request.content()
        ));
        SupportTicketStatus before = ticket.getStatus();
        Instant now = Instant.now();
        ticket.messageAdded(SupportSenderType.ADMIN, now);
        auditLogRepository.save(AdminAuditLog.create(
                admin, "SUPPORT_TICKET", ticketId, "REPLY",
                before, ticket.getStatus(), "고객지원 답변"
        ));
        realtimeEventPublisher.publish(
                ticket,
                SupportTicketRealtimeEventType.MESSAGE_ADDED,
                SupportSenderType.ADMIN,
                now
        );
        return detail(ticket);
    }

    @Transactional
    public SupportTicketDetailResponse changeStatus(
            User admin,
            Long ticketId,
            SupportTicketRequest.ChangeStatus request
    ) {
        requireAdmin(admin);
        SupportTicket ticket = findTicket(ticketId);
        SupportTicketStatus before = ticket.getStatus();
        Instant now = Instant.now();
        ticket.changeStatus(request.status());
        auditLogRepository.save(AdminAuditLog.create(
                admin, "SUPPORT_TICKET", ticketId, "CHANGE_STATUS",
                before, request.status(), "문의 상태 변경"
        ));
        realtimeEventPublisher.publish(
                ticket,
                SupportTicketRealtimeEventType.STATUS_CHANGED,
                SupportSenderType.ADMIN,
                now
        );
        return detail(ticket);
    }

    private SupportTicketDetailResponse requesterDetail(SupportTicket ticket) {
        return new SupportTicketDetailResponse(
                requesterSummary(ticket),
                messageRepository.findAllByTicketIdOrderByIdAsc(ticket.getId())
                        .stream()
                        .map(SupportMessageResponse::from)
                        .toList()
        );
    }

    private SupportTicketDetailResponse detail(SupportTicket ticket) {
        return SupportTicketDetailResponse.of(
                ticket,
                messageRepository.findAllByTicketIdOrderByIdAsc(ticket.getId())
                        .stream()
                        .map(SupportMessageResponse::from)
                        .toList()
        );
    }

    private SupportTicketSummaryResponse requesterSummary(SupportTicket ticket) {
        return SupportTicketSummaryResponse.from(
                ticket,
                unreadAdminMessageCount(ticket)
        );
    }

    private long unreadAdminMessageCount(SupportTicket ticket) {
        return messageRepository.countUnreadByTicket(
                ticket.getId(),
                SupportSenderType.ADMIN
        );
    }

    private SupportTicket findTicket(Long ticketId) {
        return ticketRepository.findById(ticketId)
                .orElseThrow(() -> new BusinessException(ErrorCode.SUPPORT_TICKET_NOT_FOUND));
    }

    private void requireOpen(SupportTicket ticket) {
        if (ticket.getStatus() == SupportTicketStatus.CLOSED) {
            throw new BusinessException(ErrorCode.SUPPORT_TICKET_CLOSED);
        }
    }

    private void requireRequesterRole(User user, SupportRequesterType requesterType) {
        PlatformRole requiredRole = requesterType == SupportRequesterType.SELLER
                ? PlatformRole.SELLER
                : PlatformRole.CUSTOMER;
        if (!user.hasRole(requiredRole)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }

    private void requireAdmin(User user) {
        if (!user.hasRole(PlatformRole.ADMIN)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }

    private PageRequest pageRequest(int page, int size) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, 100)),
                Sort.by(Sort.Direction.DESC, "lastMessageAt")
        );
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
