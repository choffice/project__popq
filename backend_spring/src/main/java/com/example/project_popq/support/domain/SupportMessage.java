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
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "support_messages")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SupportMessage extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "support_message_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "support_ticket_id", nullable = false)
    private SupportTicket ticket;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_user_id", nullable = false)
    private User sender;

    @Enumerated(EnumType.STRING)
    @Column(name = "sender_type", nullable = false, length = 30)
    private SupportSenderType senderType;

    @Column(name = "content", nullable = false, length = 4000)
    private String content;

    private SupportMessage(
            SupportTicket ticket,
            User sender,
            SupportSenderType senderType,
            String content
    ) {
        this.ticket = ticket;
        this.sender = sender;
        this.senderType = senderType;
        this.content = content.trim();
    }

    public static SupportMessage create(
            SupportTicket ticket,
            User sender,
            SupportSenderType senderType,
            String content
    ) {
        return new SupportMessage(ticket, sender, senderType, content);
    }
}
