package com.example.project_popq.analytics.service;

import com.example.project_popq.analytics.dto.SalesSummaryResponse;
import com.example.project_popq.analytics.dto.SalesSummaryResponse.DailySalesResponse;
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
import com.example.project_popq.payment.domain.Refund;
import com.example.project_popq.payment.domain.RefundStatus;
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.LocalDate;
import java.time.Instant;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
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
                Instant canceledAt = statusChangedAt(order, order.getStatus());
                if (isInRange(canceledAt, from, to)) {
                    canceledOrderCount++;
                    canceledAmount = Math.addExact(
                            canceledAmount,
                            order.getTotalAmount()
                    );
                }
            }
            if (order.getStatus() != OrderStatus.COMPLETED
                    || !isInRange(completedAt(order), from, to)) {
                continue;
            }
            long orderAmount = order.getTotalAmount();
            grossSales = Math.addExact(grossSales, orderAmount);
            completedOrderCount++;
            if (order.getOrderType() == OrderType.DINE_IN) {
                dineInSales = Math.addExact(dineInSales, orderAmount);
            } else {
                takeoutSales = Math.addExact(takeoutSales, orderAmount);
            }

            LocalDate orderDate = completedAt(order)
                    .atZone(BUSINESS_ZONE)
                    .toLocalDate();
            DailyAccumulator day = daily.get(orderDate);
            if (day != null) {
                day.sales = Math.addExact(day.sales, orderAmount);
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
        }

        for (Payment payment : payments) {
            for (Refund refund : payment.getRefunds()) {
                if (refund.getStatus() != RefundStatus.SUCCEEDED
                        || refund.getCompletedAt() == null
                        || !isInRange(refund.getCompletedAt(), from, to)) {
                    continue;
                }
                refundedAmount = Math.addExact(
                        refundedAmount,
                        refund.getAmount()
                );
                refundCount++;
                LocalDate refundDate = refund.getCompletedAt()
                        .atZone(BUSINESS_ZONE)
                        .toLocalDate();
                DailyAccumulator day = daily.get(refundDate);
                if (day != null) {
                    day.sales = Math.subtractExact(day.sales, refund.getAmount());
                }
            }
        }

        long netSales = Math.subtractExact(grossSales, refundedAmount);

        long averageOrderAmount = completedOrderCount == 0
                ? 0
                : grossSales / completedOrderCount;
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
                new ArrayList<>(topProducts)
        );
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

    private java.time.Instant completedAt(Order order) {
        return statusChangedAt(order, OrderStatus.COMPLETED);
    }

    private Instant statusChangedAt(Order order, OrderStatus status) {
        return order.getStatusHistories().stream()
                .filter(history ->
                        history.getCurrentStatus() == status
                )
                .map(OrderStatusHistory::getChangedAt)
                .max(java.time.Instant::compareTo)
                .orElse(order.getCreatedAt());
    }

    private boolean isInRange(
            Instant instant,
            LocalDate from,
            LocalDate to
    ) {
        Instant fromInclusive = from.atStartOfDay(BUSINESS_ZONE).toInstant();
        Instant toExclusive = to.plusDays(1)
                .atStartOfDay(BUSINESS_ZONE)
                .toInstant();
        return !instant.isBefore(fromInclusive) && instant.isBefore(toExclusive);
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
