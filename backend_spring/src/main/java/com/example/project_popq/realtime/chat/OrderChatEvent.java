package com.example.project_popq.realtime.chat;

import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.domain.OrderMessage;
import com.example.project_popq.inquiry.dto.OrderMessageResponse;
import com.example.project_popq.order.domain.Order;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record OrderChatEvent(
    String eventId,
    OrderChatEventType eventType,
    String orderPublicId,
    Long storeId,
    Long customerUserId,
    OrderMessageResponse message,
    List<Long> readMessageIds,
    MessageSenderType readerType,
    Instant occurredAt
) {

  public OrderChatEvent {
    readMessageIds = readMessageIds == null
        ? List.of()
        : List.copyOf(readMessageIds);
  }

  public static OrderChatEvent messageCreated(
      OrderMessage message
  ) {
    Order order = message.getOrder();

    return new OrderChatEvent(
        UUID.randomUUID().toString(),
        OrderChatEventType.MESSAGE_CREATED,
        order.getOrderPublicId(),
        order.getStore().getId(),
        resolveCustomerUserId(order),
        OrderMessageResponse.from(message),
        List.of(),
        null,
        message.getCreatedAt()
    );
  }

  public static OrderChatEvent messagesRead(
      Order order,
      MessageSenderType readerType,
      List<Long> readMessageIds,
      Instant readAt
  ) {
    return new OrderChatEvent(
        UUID.randomUUID().toString(),
        OrderChatEventType.MESSAGE_READ,
        order.getOrderPublicId(),
        order.getStore().getId(),
        resolveCustomerUserId(order),
        null,
        readMessageIds,
        readerType,
        readAt
    );
  }

  private static Long resolveCustomerUserId(
      Order order
  ) {
    return order.getUser() == null
        ? null
        : order.getUser().getId();
  }
}