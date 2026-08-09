package com.example.project_popq.order.dto;

import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderItem;
import com.example.project_popq.order.domain.OrderItemOption;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderStatusHistory;
import com.example.project_popq.order.domain.OrderType;
import java.time.Instant;
import java.util.List;

public record OrderResponse(
        String orderPublicId,
        Long storeId,
        String storeName,
        OrderType orderType,
        String requestMessage,
        OrderStatus status,
        long subtotalAmount,
        long discountAmount,
        long taxAmount,
        long serviceFeeAmount,
        long totalAmount,
        Instant expiresAt,
        Instant createdAt,
        Instant acceptedAt,
        Integer preparationMinutes,
        Instant estimatedReadyAt,
        long version,
        List<OrderItemResponse> items,
        List<OrderStatusHistoryResponse> statusHistory
) {
    public static OrderResponse from(Order order) {
        return new OrderResponse(
                order.getOrderPublicId(),
                order.getStore().getId(),
                order.getStore().getName(),
                order.getOrderType(),
                order.getRequestMessage(),
                order.getStatus(),
                order.getSubtotalAmount(),
                order.getDiscountAmount(),
                order.getTaxAmount(),
                order.getServiceFeeAmount(),
                order.getTotalAmount(),
                order.getExpiresAt(),
                order.getCreatedAt(),
                order.getAcceptedAt(),
                order.getPreparationMinutes(),
                order.getEstimatedReadyAt(),
                order.getVersion(),
                order.getItems().stream()
                        .map(OrderItemResponse::from)
                        .toList(),
                order.getStatusHistories().stream()
                        .map(OrderStatusHistoryResponse::from)
                        .toList()
        );
    }

    public record OrderItemResponse(
            Long orderItemId,
            Long productId,
            String productName,
            String productImageUrl,
            long unitPrice,
            int quantity,
            long itemTotalPrice,
            List<OrderItemOptionResponse> options
    ) {
        private static OrderItemResponse from(OrderItem item) {
            return new OrderItemResponse(
                    item.getId(),
                    item.getProduct().getId(),
                    item.getProductNameSnapshot(),
                    item.getProductImageUrlSnapshot(),
                    item.getUnitPriceSnapshot(),
                    item.getQuantity(),
                    item.getItemTotalPrice(),
                    item.getOptions().stream()
                            .map(OrderItemOptionResponse::from)
                            .toList()
            );
        }
    }

    public record OrderItemOptionResponse(
            Long productOptionId,
            String optionGroupName,
            String optionName,
            long optionPrice
    ) {
        private static OrderItemOptionResponse from(
                OrderItemOption option
        ) {
            return new OrderItemOptionResponse(
                    option.getProductOption().getId(),
                    option.getOptionGroupNameSnapshot(),
                    option.getOptionNameSnapshot(),
                    option.getOptionPriceSnapshot()
            );
        }
    }

    public record OrderStatusHistoryResponse(
            OrderStatus previousStatus,
            OrderStatus currentStatus,
            String actorType,
            Long actorId,
            String reason,
            Instant changedAt
    ) {
        private static OrderStatusHistoryResponse from(
                OrderStatusHistory history
        ) {
            return new OrderStatusHistoryResponse(
                    history.getPreviousStatus(),
                    history.getCurrentStatus(),
                    history.getActorType().name(),
                    history.getActorId(),
                    history.getReason(),
                    history.getChangedAt()
            );
        }
    }
}