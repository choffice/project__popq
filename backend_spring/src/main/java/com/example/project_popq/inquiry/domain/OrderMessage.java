package com.example.project_popq.inquiry.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.order.domain.Order;
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
@Table(name = "order_messages")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class OrderMessage extends BaseTimeEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "order_message_id")
  private Long id;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "order_id", nullable = false)
  private Order order;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "sender_user_id", nullable = false)
  private User sender;

  @Enumerated(EnumType.STRING)
  @Column(name = "sender_type", nullable = false, length = 30)
  private MessageSenderType senderType;

  @Column(name = "client_message_id", length = 64)
  private String clientMessageId;

  @Column(name = "content", nullable = false, length = 2000)
  private String content;

  @Column(name = "read_at")
  private Instant readAt;

  private OrderMessage(
      Order order,
      User sender,
      MessageSenderType senderType,
      String clientMessageId,
      String content
  ) {
    this.order = order;
    this.sender = sender;
    this.senderType = senderType;
    this.clientMessageId = normalizeClientMessageId(clientMessageId);
    this.content = content;
  }

  /**
   * clientMessageId를 사용하는 새로운 메시지 생성 방식입니다.
   *
   * WebSocket 또는 REST 재전송 시 동일한 clientMessageId를 전달하면
   * 서버에서 중복 저장 여부를 확인할 수 있습니다.
   */
  public static OrderMessage create(
      Order order,
      User sender,
      MessageSenderType senderType,
      String clientMessageId,
      String content
  ) {
    return new OrderMessage(
        order,
        sender,
        senderType,
        clientMessageId,
        content
    );
  }

  /**
   * 기존 REST 메시지 전송 코드와의 호환성을 위한 생성 메서드입니다.
   *
   * 다음 단계에서 메시지 전송 요청 DTO와 서비스를 변경한 뒤에도
   * 기존 호출 코드가 갑자기 깨지지 않도록 유지합니다.
   */
  public static OrderMessage create(
      Order order,
      User sender,
      MessageSenderType senderType,
      String content
  ) {
    return new OrderMessage(
        order,
        sender,
        senderType,
        null,
        content
    );
  }

  public void markAsRead(Instant now) {
    if (readAt == null) {
      readAt = now;
    }
  }

  public boolean isRead() {
    return readAt != null;
  }

  public boolean isSentBy(MessageSenderType senderType) {
    return this.senderType == senderType;
  }

  public boolean hasClientMessageId() {
    return clientMessageId != null;
  }

  private static String normalizeClientMessageId(
      String clientMessageId
  ) {
    if (clientMessageId == null) {
      return null;
    }

    String normalized = clientMessageId.trim();

    if (normalized.isEmpty()) {
      return null;
    }

    return normalized;
  }
}