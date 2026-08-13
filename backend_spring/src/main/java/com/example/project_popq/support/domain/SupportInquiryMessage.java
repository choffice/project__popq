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
@Table(name = "support_inquiry_messages")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SupportInquiryMessage extends BaseTimeEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "support_inquiry_message_id")
  private Long id;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "support_inquiry_id", nullable = false)
  private SupportInquiry inquiry;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "sender_user_id", nullable = false)
  private User sender;

  @Enumerated(EnumType.STRING)
  @Column(name = "sender_type", nullable = false, length = 30)
  private SupportMessageSenderType senderType;

  @Column(name = "content", nullable = false, length = 3000)
  private String content;

  @Column(name = "read_at")
  private Instant readAt;

  private SupportInquiryMessage(
      SupportInquiry inquiry,
      User sender,
      SupportMessageSenderType senderType,
      String content
  ) {
    this.inquiry = inquiry;
    this.sender = sender;
    this.senderType = senderType;
    this.content = content;
  }

  public static SupportInquiryMessage create(
      SupportInquiry inquiry,
      User sender,
      SupportMessageSenderType senderType,
      String content
  ) {
    return new SupportInquiryMessage(
        inquiry,
        sender,
        senderType,
        content
    );
  }

  public void markAsRead(Instant now) {
    if (this.readAt == null) {
      this.readAt = now;
    }
  }

  public boolean isRead() {
    return this.readAt != null;
  }

  public boolean isSentBy(
      SupportMessageSenderType senderType
  ) {
    return this.senderType == senderType;
  }
}