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
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.payment.domain.Refund;
import com.example.project_popq.payment.domain.RefundStatus;
import com.example.project_popq.payment.repository.PaymentRepository;
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
    private final PaymentRepository paymentRepository =
        mock(PaymentRepository.class);
    private final SalesAnalyticsService service = new SalesAnalyticsService(
        orderRepository,
        paymentRepository,
        authorizationService
    );

    @Test
    void aggregatesApprovedPaymentsAndSuccessfulRefunds() {
        Order dineIn = order(
            OrderStatus.COMPLETED,
            OrderType.DINE_IN,
            12_000,
            "2026-07-27T01:00:00Z",
            List.of(item("라떼", 2, 12_000))
        );
        Order takeout = order(
            OrderStatus.COMPLETED,
            OrderType.TAKEOUT,
            8_000,
            "2026-07-28T02:00:00Z",
            List.of(
                item("라떼", 1, 6_000),
                item("케이크", 1, 2_000)
            )
        );

        Refund partialRefund = refund(
            3_000,
            RefundStatus.SUCCEEDED,
            "2026-07-29T00:00:00Z"
        );

        Payment firstPayment = payment(
            dineIn,
            PaymentStatus.PAID,
            12_000,
            "2026-07-27T01:00:00Z",
            List.of()
        );
        Payment secondPayment = payment(
            takeout,
            PaymentStatus.PARTIALLY_REFUNDED,
            8_000,
            "2026-07-28T02:00:00Z",
            List.of(partialRefund)
        );

        SalesSummaryResponse result = service.aggregate(
            LocalDate.of(2026, 7, 27),
            LocalDate.of(2026, 7, 29),
            List.of(dineIn, takeout),
            List.of(firstPayment, secondPayment)
        );

        assertThat(result.grossSales()).isEqualTo(20_000);
        assertThat(result.refundedAmount()).isEqualTo(3_000);
        assertThat(result.refundCount()).isEqualTo(1);
        assertThat(result.netSales()).isEqualTo(17_000);
        assertThat(result.completedOrderCount()).isEqualTo(2);
        assertThat(result.averageOrderAmount()).isEqualTo(10_000);
        assertThat(result.dineInSales()).isEqualTo(12_000);
        assertThat(result.takeoutSales()).isEqualTo(8_000);
        assertThat(result.dailySales())
            .extracting("sales")
            .containsExactly(12_000L, 8_000L, -3_000L);
        assertThat(result.topProducts()).hasSize(2);
        assertThat(result.topProducts().get(0).productName()).isEqualTo("라떼");
        assertThat(result.topProducts().get(0).quantity()).isEqualTo(3);
        assertThat(result.topProducts().get(0).sales()).isEqualTo(18_000);
    }

    @Test
    void canceledPaymentKeepsApprovalAndSubtractsSuccessfulCancellation() {
        Order canceled = order(
            OrderStatus.CANCELED,
            OrderType.DINE_IN,
            9_000,
            "2026-07-28T03:00:00Z",
            List.of(item("취소 상품", 1, 9_000))
        );
        Refund cancellation = refund(
            9_000,
            RefundStatus.SUCCEEDED,
            "2026-07-28T03:10:00Z"
        );
        Payment payment = payment(
            canceled,
            PaymentStatus.CANCELED,
            9_000,
            "2026-07-28T03:00:00Z",
            List.of(cancellation)
        );

        SalesSummaryResponse result = service.aggregate(
            LocalDate.of(2026, 7, 28),
            LocalDate.of(2026, 7, 28),
            List.of(canceled),
            List.of(payment)
        );

        assertThat(result.grossSales()).isEqualTo(9_000);
        assertThat(result.refundedAmount()).isEqualTo(9_000);
        assertThat(result.netSales()).isZero();
        assertThat(result.canceledOrderCount()).isEqualTo(1);
        assertThat(result.canceledAmount()).isEqualTo(9_000);
    }

    @Test
    void excludesUnapprovedPaymentStatusesFromSales() {
        Order order = order(
            OrderStatus.CREATED,
            OrderType.TAKEOUT,
            5_000,
            "2026-07-28T03:00:00Z",
            List.of(item("미승인 상품", 1, 5_000))
        );

        Payment ready = payment(
            order,
            PaymentStatus.READY,
            null,
            null,
            List.of()
        );
        Payment failed = payment(
            order,
            PaymentStatus.FAILED,
            null,
            null,
            List.of()
        );

        SalesSummaryResponse result = service.aggregate(
            LocalDate.of(2026, 7, 28),
            LocalDate.of(2026, 7, 28),
            List.of(order),
            List.of(ready, failed)
        );

        assertThat(result.grossSales()).isZero();
        assertThat(result.refundedAmount()).isZero();
        assertThat(result.netSales()).isZero();
        assertThat(result.topProducts()).isEmpty();
    }

    @Test
    void usesAsiaSeoulBusinessDateForApproval() {
        Order order = order(
            OrderStatus.PLACED,
            OrderType.TAKEOUT,
            7_000,
            "2026-07-26T15:30:00Z",
            List.of(item("자정 주문", 1, 7_000))
        );
        Payment payment = payment(
            order,
            PaymentStatus.PAID,
            7_000,
            "2026-07-26T15:30:00Z",
            List.of()
        );

        SalesSummaryResponse result = service.aggregate(
            LocalDate.of(2026, 7, 27),
            LocalDate.of(2026, 7, 27),
            List.of(order),
            List.of(payment)
        );

        assertThat(result.grossSales()).isEqualTo(7_000);
        assertThat(result.dailySales()).singleElement()
            .satisfies(day -> {
                assertThat(day.date()).isEqualTo(LocalDate.of(2026, 7, 27));
                assertThat(day.sales()).isEqualTo(7_000);
                assertThat(day.orderCount()).isEqualTo(1);
            });
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
        String statusChangedAt,
        List<OrderItem> items
    ) {
        Order order = mock(Order.class);
        when(order.getStatus()).thenReturn(status);
        when(order.getOrderType()).thenReturn(type);
        when(order.getTotalAmount()).thenReturn(amount);
        when(order.getItems()).thenReturn(items);

        Instant timestamp = Instant.parse(statusChangedAt);
        when(order.getCreatedAt()).thenReturn(timestamp);

        OrderStatusHistory history = mock(OrderStatusHistory.class);
        when(history.getCurrentStatus()).thenReturn(status);
        when(history.getChangedAt()).thenReturn(timestamp);
        when(order.getStatusHistories()).thenReturn(List.of(history));

        return order;
    }

    private Payment payment(
        Order order,
        PaymentStatus status,
        Integer approvedAmount,
        String approvedAt,
        List<Refund> refunds
    ) {
        Payment payment = mock(Payment.class);
        when(payment.getOrder()).thenReturn(order);
        when(payment.getStatus()).thenReturn(status);
        when(payment.getApprovedAmount()).thenReturn(
            approvedAmount == null ? null : approvedAmount.longValue()
        );
        when(payment.getApprovedAt()).thenReturn(
            approvedAt == null ? null : Instant.parse(approvedAt)
        );
        when(payment.getRefunds()).thenReturn(refunds);
        return payment;
    }

    private Refund refund(
        long amount,
        RefundStatus status,
        String completedAt
    ) {
        Refund refund = mock(Refund.class);
        when(refund.getAmount()).thenReturn(amount);
        when(refund.getStatus()).thenReturn(status);
        when(refund.getCompletedAt()).thenReturn(
            completedAt == null ? null : Instant.parse(completedAt)
        );
        return refund;
    }

    private OrderItem item(String name, int quantity, long sales) {
        OrderItem item = mock(OrderItem.class);
        when(item.getProductNameSnapshot()).thenReturn(name);
        when(item.getQuantity()).thenReturn(quantity);
        when(item.getItemTotalPrice()).thenReturn(sales);
        return item;
    }
}