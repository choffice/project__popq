package com.example.project_popq.inquiry.dto;

import com.example.project_popq.inquiry.domain.OrderMessage;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderItem;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderType;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.List;

public record SellerConversationDetailResponse(
    String orderPublicId,
    Long storeId,
    String storeName,
    Long customerUserId,
    String customerName,
    OrderType orderType,
    OrderStatus orderStatus,
    long totalAmount,
    Instant orderedAt,
    List<OrderItemSummary> orderItems,
    List<OrderMessageResponse> messages
) {

  public static SellerConversationDetailResponse of(
      Order order,
      List<OrderMessage> messages
  ) {
    User customer = order.getUser();

    return new SellerConversationDetailResponse(
        order.getOrderPublicId(),
        order.getStore().getId(),
        order.getStore().getName(),
        customer == null ? null : customer.getId(),
        customer == null ? "고객 정보 없음" : customer.getName(),
        order.getOrderType(),
        order.getStatus(),
        order.getTotalAmount(),
        order.getCreatedAt(),
        order.getItems().stream()
            .map(OrderItemSummary::from)
            .toList(),
        messages.stream()
            .map(OrderMessageResponse::from)
            .toList()
    );
  }

  public record OrderItemSummary(
      Long orderItemId,
      String productName,
      int quantity,
      long itemTotalPrice
  ) {

    private static OrderItemSummary from(OrderItem item) {
      return new OrderItemSummary(
          item.getId(),
          item.getProductNameSnapshot(),
          item.getQuantity(),
          item.getItemTotalPrice()
      );
    }
  }
}