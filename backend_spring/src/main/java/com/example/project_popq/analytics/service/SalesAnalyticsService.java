package com.example.project_popq.analytics.service;

import com.example.project_popq.analytics.dto.SalesSummaryResponse;
import com.example.project_popq.analytics.dto.SalesSummaryResponse.CancellationDetailResponse;
import com.example.project_popq.analytics.dto.SalesSummaryResponse.DailySalesResponse;
import com.example.project_popq.analytics.dto.SalesSummaryResponse.OrderSalesDetailResponse;
import com.example.project_popq.analytics.dto.SalesSummaryResponse.RefundDetailResponse;
import com.example.project_popq.analytics.dto.SalesSummaryResponse.TopProductResponse;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
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
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.IdentityHashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SalesAnalyticsService {

    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Seoul");
    private static final int MAX_RANGE_DAYS = 31;

    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;
    private final StoreAuthorizationService storeAuthorizationService;

    @Transactional(readOnly = true)
    public SalesSummaryResponse summarize(
        User currentUser,
        Long storeId,
        LocalDate from,
        LocalDate to
    ) {
        validateRange(from, to);
        storeAuthorizationService.requireAnyRole(
            currentUser.getId(),
            storeId,
            StoreRole.OWNER,
            StoreRole.MANAGER,
            StoreRole.STAFF
        );

        List<Order> orders = orderRepository
            .findAllByStoreIdOrderByCreatedAtAsc(storeId);
        List<Payment> payments = paymentRepository
            .findAllForStoreAnalytics(storeId);

        return aggregate(from, to, orders, payments);
    }

    SalesSummaryResponse aggregate(
        LocalDate from,
        LocalDate to,
        List<Order> orders
    ) {
        return aggregate(from, to, orders, List.of());
    }

    SalesSummaryResponse aggregate(
        LocalDate from,
        LocalDate to,
        List<Order> orders,
        List<Payment> payments
    ) {
        Map<LocalDate, DailyAccumulator> daily = new LinkedHashMap<>();
        from.datesUntil(to.plusDays(1))
            .forEach(date -> daily.put(date, new DailyAccumulator()));

        Map<String, ProductAccumulator> products = new LinkedHashMap<>();
        Map<Order, Payment> paymentsByOrder = new IdentityHashMap<>();
        payments.forEach(payment -> paymentsByOrder.put(
            payment.getOrder(),
            payment
        ));

        List<OrderSalesDetailResponse> orderHistory = new ArrayList<>();
        List<RefundDetailResponse> refundHistory = new ArrayList<>();
        List<CancellationDetailResponse> cancellationHistory =
            new ArrayList<>();

        long grossSales = 0;
        long refundedAmount = 0;
        int refundCount = 0;
        int canceledOrderCount = 0;
        long canceledAmount = 0;
        long dineInSales = 0;
        long takeoutSales = 0;
        int completedOrderCount = 0;

        for (Order order : orders) {
            if (order.getStatus() == OrderStatus.CANCELED
                || order.getStatus() == OrderStatus.REJECTED) {
                OrderStatusHistory cancellation = latestStatusHistory(
                    order,
                    order.getStatus()
                );
                Instant canceledAt = cancellation == null
                    ? order.getCreatedAt()
                    : cancellation.getChangedAt();
                if (isInRange(canceledAt, from, to)) {
                    canceledOrderCount++;
                    canceledAmount = Math.addExact(
                        canceledAmount,
                        order.getTotalAmount()
                    );
                    cancellationHistory.add(new CancellationDetailResponse(
                        order.getOrderPublicId(),
                        order.getStatus(),
                        order.getTotalAmount(),
                        cancellation == null ? null : cancellation.getReason(),
                        canceledAt
                    ));
                }
            }

            if (order.getStatus() != OrderStatus.COMPLETED) {
                continue;
            }

            Instant completedAt = completedAt(order);
            if (!isInRange(completedAt, from, to)) {
                continue;
            }

            completedOrderCount++;
            Payment payment = paymentsByOrder.get(order);
            long approvedAmount = 0;
            long orderRefundedAmount = 0;
            long orderNetSales = 0;

            if (payment != null && isApprovedPayment(payment)) {
                approvedAmount = payment.getApprovedAmount();
                grossSales = Math.addExact(grossSales, approvedAmount);

                for (Refund refund : payment.getRefunds()) {
                    if (refund.getStatus() != RefundStatus.SUCCEEDED) {
                        continue;
                    }

                    orderRefundedAmount = Math.addExact(
                        orderRefundedAmount,
                        refund.getAmount()
                    );
                    refundCount++;
                    refundHistory.add(new RefundDetailResponse(
                        refund.getId(),
                        order.getOrderPublicId(),
                        refund.getAmount(),
                        refund.getReason(),
                        refund.getRequesterType() == null
                            ? "UNKNOWN"
                            : refund.getRequesterType().name(),
                        refund.getCompletedAt()
                    ));
                }

                refundedAmount = Math.addExact(
                    refundedAmount,
                    orderRefundedAmount
                );
                orderNetSales = Math.max(
                    0,
                    Math.subtractExact(approvedAmount, orderRefundedAmount)
                );

                if (order.getOrderType() == OrderType.DINE_IN) {
                    dineInSales = Math.addExact(dineInSales, orderNetSales);
                } else {
                    takeoutSales = Math.addExact(takeoutSales, orderNetSales);
                }
            }

            LocalDate completedDate = completedAt
                    .atZone(BUSINESS_ZONE)
                    .toLocalDate();
            DailyAccumulator day = daily.get(completedDate);
            if (day != null) {
                day.sales = Math.addExact(day.sales, orderNetSales);
                day.orderCount++;
            }

            for (OrderItem item : order.getItems()) {
                ProductAccumulator product = products.computeIfAbsent(
                    item.getProductNameSnapshot(),
                    ignored -> new ProductAccumulator()
                );
                product.quantity = Math.addExact(
                    product.quantity,
                    item.getQuantity()
                );
                product.sales = Math.addExact(
                    product.sales,
                    item.getItemTotalPrice()
                );
            }

            int itemCount = order.getItems().stream()
                .mapToInt(OrderItem::getQuantity)
                .sum();
            orderHistory.add(new OrderSalesDetailResponse(
                order.getOrderPublicId(),
                order.getOrderType(),
                approvedAmount,
                orderRefundedAmount,
                orderNetSales,
                completedAt,
                itemCount,
                itemSummary(order)
            ));
        }

        long netSales = Math.subtractExact(grossSales, refundedAmount);
        long averageOrderAmount = completedOrderCount == 0
            ? 0
            : netSales / completedOrderCount;

        List<DailySalesResponse> dailySales = daily.entrySet().stream()
            .map(entry -> new DailySalesResponse(
                entry.getKey(),
                entry.getValue().sales,
                entry.getValue().orderCount
            ))
            .toList();

        List<TopProductResponse> topProducts = products.entrySet().stream()
            .map(entry -> new TopProductResponse(
                entry.getKey(),
                entry.getValue().quantity,
                entry.getValue().sales
            ))
            .sorted(
                Comparator.comparingLong(TopProductResponse::sales)
                    .reversed()
                    .thenComparing(TopProductResponse::productName)
            )
            .limit(5)
            .toList();

        orderHistory.sort(Comparator.comparing(
            OrderSalesDetailResponse::completedAt,
            Comparator.nullsLast(Comparator.reverseOrder())
        ));
        refundHistory.sort(Comparator.comparing(
            RefundDetailResponse::completedAt,
            Comparator.nullsLast(Comparator.reverseOrder())
        ));
        cancellationHistory.sort(Comparator.comparing(
            CancellationDetailResponse::canceledAt,
            Comparator.nullsLast(Comparator.reverseOrder())
        ));

        return new SalesSummaryResponse(
            from,
            to,
            grossSales,
            netSales,
            refundedAmount,
            refundCount,
            canceledOrderCount,
            canceledAmount,
            completedOrderCount,
            averageOrderAmount,
            dineInSales,
            takeoutSales,
            new ArrayList<>(dailySales),
            new ArrayList<>(topProducts),
            orderHistory,
            refundHistory,
            cancellationHistory
        );
    }

    private boolean isApprovedPayment(Payment payment) {
        if (payment.getApprovedAmount() == null
            || payment.getApprovedAt() == null) {
            return false;
        }

        return switch (payment.getStatus()) {
            case PAID, PARTIALLY_REFUNDED, REFUNDED, CANCELED -> true;
            case READY, IN_PROGRESS, FAILED -> false;
        };
    }

    private void validateRange(LocalDate from, LocalDate to) {
        if (from == null || to == null || from.isAfter(to)) {
            throw new BusinessException(
                ErrorCode.INVALID_REQUEST,
                "유효한 매출 조회 기간이 필요합니다."
            );
        }

        if (ChronoUnit.DAYS.between(from, to) + 1 > MAX_RANGE_DAYS) {
            throw new BusinessException(
                ErrorCode.INVALID_REQUEST,
                "매출 조회 기간은 최대 31일입니다."
            );
        }
    }

    private Instant completedAt(Order order) {
        return statusChangedAt(order, OrderStatus.COMPLETED);
    }

    private String itemSummary(Order order) {
        if (order.getItems().isEmpty()) {
            return "주문 상품 없음";
        }
        String firstProduct = order.getItems().get(0).getProductNameSnapshot();
        int remaining = order.getItems().size() - 1;
        return remaining == 0
            ? firstProduct
            : firstProduct + " 외 " + remaining + "개";
    }

    private Instant statusChangedAt(Order order, OrderStatus status) {
        OrderStatusHistory history = latestStatusHistory(order, status);
        return history == null ? order.getCreatedAt() : history.getChangedAt();
    }

    private OrderStatusHistory latestStatusHistory(
        Order order,
        OrderStatus status
    ) {
        return order.getStatusHistories().stream()
            .filter(history -> history.getCurrentStatus() == status)
            .max(Comparator.comparing(OrderStatusHistory::getChangedAt))
            .orElse(null);
    }

    private boolean isInRange(
        Instant instant,
        LocalDate from,
        LocalDate to
    ) {
        if (instant == null) {
            return false;
        }

        Instant fromInclusive = from.atStartOfDay(BUSINESS_ZONE).toInstant();
        Instant toExclusive = to.plusDays(1)
            .atStartOfDay(BUSINESS_ZONE)
            .toInstant();

        return !instant.isBefore(fromInclusive)
            && instant.isBefore(toExclusive);
    }

    private static final class DailyAccumulator {
        private long sales;
        private int orderCount;
    }

    private static final class ProductAccumulator {
        private int quantity;
        private long sales;
    }
}
