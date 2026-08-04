package com.example.project_popq.inquiry.dto;

import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.domain.OrderMessage;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.user.domain.User;
import java.time.Instant;

public record SellerConversationSummaryResponse(
    String orderPublicId,
    Long customerUserId,
    String customerName,
    OrderStatus orderStatus,
    String lastMessage,
    MessageSenderType lastMessageSenderType,
    Instant lastMessageAt,
    long unreadCount
) {

  public static SellerConversationSummaryResponse of(
      OrderMessage latestMessage,
      long unreadCount
  ) {
    Order order = latestMessage.getOrder();
    User customer = order.getUser();

    return new SellerConversationSummaryResponse(
        order.getOrderPublicId(),
        customer == null ? null : customer.getId(),
        customer == null ? "고객 정보 없음" : customer.getName(),
        order.getStatus(),
        latestMessage.getContent(),
        latestMessage.getSenderType(),
        latestMessage.getCreatedAt(),
        unreadCount
    );
  }
}