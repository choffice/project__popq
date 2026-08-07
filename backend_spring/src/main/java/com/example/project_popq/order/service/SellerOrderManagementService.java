package com.example.project_popq.order.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderActorType;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderTransition;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.realtime.event.OrderDomainEventPublisher;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.store.service.StoreOperatingHoursPolicy;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SellerOrderManagementService {

    private static final Set<Integer> PREPARATION_MINUTES = Set.of(
            0, 5, 10, 15, 20, 30, 40, 50
    );
    private static final Set<OrderStatus> TERMINAL_STATUSES = Set.of(
            OrderStatus.COMPLETED,
            OrderStatus.CANCELED,
            OrderStatus.REJECTED,
            OrderStatus.EXPIRED
    );

    private final StoreAuthorizationService storeAuthorizationService;
    private final OrderRepository orderRepository;
    private final OrderDomainEventPublisher orderEventPublisher;

    @Transactional(readOnly = true)
    public List<OrderResponse> findSellerOrders(
            User user,
            Long storeId,
            OrderStatus status,
            List<OrderStatus> statuses,
            LocalDate date
    ) {
        requireStoreMember(user.getId(), storeId);
        List<Order> orders;
        if (date != null) {
            List<OrderStatus> requestedStatuses = status != null
                    ? List.of(status)
                    : statuses == null || statuses.isEmpty()
                    ? List.copyOf(TERMINAL_STATUSES)
                    : statuses;
            if (!TERMINAL_STATUSES.containsAll(requestedStatuses)) {
                throw new BusinessException(ErrorCode.INVALID_REQUEST);
            }
            Instant fromInclusive = date.atStartOfDay(
                    StoreOperatingHoursPolicy.BUSINESS_ZONE
            ).toInstant();
            Instant toExclusive = date.plusDays(1).atStartOfDay(
                    StoreOperatingHoursPolicy.BUSINESS_ZONE
            ).toInstant();
            orders = orderRepository
                    .findAllByStoreIdAndStatusInAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByCreatedAtDesc(
                            storeId,
                            requestedStatuses,
                            fromInclusive,
                            toExclusive
                    );
        } else if (status != null) {
            orders = orderRepository.findAllByStoreIdAndStatusOrderByCreatedAtDesc(
                    storeId,
                    status
            );
        } else if (statuses != null && !statuses.isEmpty()) {
            orders = orderRepository.findAllByStoreIdAndStatusInOrderByCreatedAtDesc(
                    storeId,
                    statuses
            );
        } else {
            orders = orderRepository.findAllByStoreIdOrderByCreatedAtDesc(storeId);
        }
        return orders.stream().map(OrderResponse::from).toList();
    }

    @Transactional
    public OrderResponse acceptBySeller(
            User user,
            Long storeId,
            String orderPublicId,
            int preparationMinutes,
            boolean applyAsStoreDefault,
            String reason
    ) {
        requireStoreMember(user.getId(), storeId);
        if (!PREPARATION_MINUTES.contains(preparationMinutes)) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
        Order order = lockedSellerOrder(storeId, orderPublicId);
        Instant now = Instant.now();
        OrderTransition transition = order.accept(
                preparationMinutes,
                OrderActorType.SELLER,
                user.getId(),
                reason,
                now
        );
        if (applyAsStoreDefault) {
            order.getStore().changeDefaultPreparationMinutes(preparationMinutes);
        }
        orderRepository.flush();
        orderEventPublisher.publish(order, transition);
        return OrderResponse.from(order);
    }

    private Order lockedSellerOrder(Long storeId, String orderPublicId) {
        Order order = orderRepository.findForUpdateByOrderPublicId(orderPublicId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ORDER_NOT_FOUND));
        if (!order.getStore().getId().equals(storeId)) {
            throw new BusinessException(ErrorCode.ORDER_NOT_FOUND);
        }
        return order;
    }

    private void requireStoreMember(Long userId, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                userId,
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
    }
}
