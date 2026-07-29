package com.example.project_popq.analytics.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.example.project_popq.analytics.dto.SalesSummaryResponse;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderItem;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderStatusHistory;
import com.example.project_popq.order.domain.OrderType;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class SalesAnalyticsServiceTests {

    private final OrderRepository orderRepository = mock(OrderRepository.class);
    private final StoreAuthorizationService authorizationService =
            mock(StoreAuthorizationService.class);
    private final SalesAnalyticsService service = new SalesAnalyticsService(
            orderRepository,
            authorizationService
    );

    @Test
    void aggregatesCompletedOrdersByDayTypeAndProduct() {
        OrderItem firstLatte = item("라떼", 2, 12_000);
        OrderItem secondLatte = item("라떼", 1, 6_000);
        OrderItem cake = item("케이크", 1, 2_000);
        Order dineIn = order(
                OrderStatus.COMPLETED,
                OrderType.DINE_IN,
                12_000,
                "2026-07-27T01:00:00Z",
                List.of(firstLatte)
        );
        Order takeout = order(
                OrderStatus.COMPLETED,
                OrderType.TAKEOUT,
                8_000,
                "2026-07-28T02:00:00Z",
                List.of(secondLatte, cake)
        );
        Order canceled = order(
                OrderStatus.CANCELED,
                OrderType.DINE_IN,
                9_000,
                "2026-07-28T03:00:00Z",
                List.of(item("취소 상품", 1, 9_000))
        );

        SalesSummaryResponse result = service.aggregate(
                LocalDate.of(2026, 7, 27),
                LocalDate.of(2026, 7, 29),
                List.of(dineIn, takeout, canceled)
        );

        assertThat(result.netSales()).isEqualTo(20_000);
        assertThat(result.completedOrderCount()).isEqualTo(2);
        assertThat(result.averageOrderAmount()).isEqualTo(10_000);
        assertThat(result.dineInSales()).isEqualTo(12_000);
        assertThat(result.takeoutSales()).isEqualTo(8_000);
        assertThat(result.dailySales())
                .extracting("sales")
                .containsExactly(12_000L, 8_000L, 0L);
        assertThat(result.topProducts()).hasSize(2);
        assertThat(result.topProducts().get(0).productName()).isEqualTo("라떼");
        assertThat(result.topProducts().get(0).quantity()).isEqualTo(3);
        assertThat(result.topProducts().get(0).sales()).isEqualTo(18_000);
    }

    @Test
    void rejectsRangesLongerThanThirtyOneDays() {
        User user = mock(User.class);
        when(user.getId()).thenReturn(1L);

        assertThatThrownBy(() -> service.summarize(
                user,
                1L,
                LocalDate.of(2026, 1, 1),
                LocalDate.of(2026, 2, 1)
        )).isInstanceOf(BusinessException.class)
                .hasMessageContaining("최대 31일");
    }

    private Order order(
            OrderStatus status,
            OrderType type,
            long amount,
            String createdAt,
            List<OrderItem> items
    ) {
        Order order = mock(Order.class);
        when(order.getStatus()).thenReturn(status);
        when(order.getOrderType()).thenReturn(type);
        when(order.getTotalAmount()).thenReturn(amount);
        Instant timestamp = Instant.parse(createdAt);
        when(order.getCreatedAt()).thenReturn(timestamp);
        when(order.getItems()).thenReturn(items);
        OrderStatusHistory history = mock(OrderStatusHistory.class);
        when(history.getCurrentStatus()).thenReturn(status);
        when(history.getChangedAt()).thenReturn(timestamp);
        when(order.getStatusHistories()).thenReturn(List.of(history));
        return order;
    }

    private OrderItem item(String name, int quantity, long sales) {
        OrderItem item = mock(OrderItem.class);
        when(item.getProductNameSnapshot()).thenReturn(name);
        when(item.getQuantity()).thenReturn(quantity);
        when(item.getItemTotalPrice()).thenReturn(sales);
        return item;
    }
}
