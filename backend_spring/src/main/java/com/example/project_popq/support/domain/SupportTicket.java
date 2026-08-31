package com.example.project_popq.support.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.user.domain.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "support_tickets")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SupportTicket extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "support_ticket_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requester_user_id", nullable = false)
    private User requester;

    @Enumerated(EnumType.STRING)
    @Column(name = "requester_type", nullable = false, length = 30)
    private SupportRequesterType requesterType;

    @Enumerated(EnumType.STRING)
    @Column(name = "category", nullable = false, length = 50)
    private SupportCategory category;

    @Column(name = "subject", nullable = false, length = 200)
    private String subject;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 40)
    private SupportTicketStatus status;

    @Column(name = "last_message_at", nullable = false)
    private Instant lastMessageAt;

    @Column(name = "requester_read_at")
    private Instant requesterReadAt;

    private SupportTicket(
            User requester,
            SupportRequesterType requesterType,
            SupportCategory category,
            String subject,
            Instant now
    ) {
        this.requester = requester;
        this.requesterType = requesterType;
        this.category = category;
        this.subject = subject.trim();
        this.status = SupportTicketStatus.RECEIVED;
        this.lastMessageAt = now;
        this.requesterReadAt = now;
    }

    public static SupportTicket create(
            User requester,
            SupportRequesterType requesterType,
            SupportCategory category,
            String subject,
            Instant now
    ) {
        return new SupportTicket(requester, requesterType, category, subject, now);
    }

    public void messageAdded(SupportSenderType senderType, Instant now) {
        this.lastMessageAt = now;
        this.status = senderType == SupportSenderType.ADMIN
                ? SupportTicketStatus.WAITING_REQUESTER
                : SupportTicketStatus.WAITING_ADMIN;
    }

    public void markRequesterRead(Instant now) {
        this.requesterReadAt = now;
    }

    public void changeStatus(SupportTicketStatus status) {
        this.status = status;
    }
}
