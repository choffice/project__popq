package com.example.project_popq.order.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderActorType;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderTransition;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.dto.OrderSyncResponse;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.payment.domain.PaymentTransaction;
import com.example.project_popq.payment.domain.PaymentTransactionType;
import com.example.project_popq.payment.domain.Refund;
import com.example.project_popq.payment.domain.RefundRequesterType;
import com.example.project_popq.payment.provider.PaymentCancellationCommand;
import com.example.project_popq.payment.provider.PaymentCancellationResult;
import com.example.project_popq.payment.provider.PaymentProvider;
import com.example.project_popq.payment.provider.PaymentProviderRegistry;
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.payment.service.RefundProcessingException;
import com.example.project_popq.point.service.CustomerPointService;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import com.example.project_popq.realtime.event.OrderDomainEventPublisher;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class OrderCommandService {

    private final GuestQrService guestQrService;
    private final GuestOrderService guestOrderService;
    private final StoreAuthorizationService storeAuthorizationService;
    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;
    private final PaymentProviderRegistry paymentProviderRegistry;
    private final OrderDomainEventPublisher orderEventPublisher;
    private final CustomerPointService customerPointService;

    @Transactional(noRollbackFor = RefundProcessingException.class)
    public OrderResponse cancelByGuest(
            String rawSessionToken,
            String orderPublicId,
            String reason
    ) {
        ResolvedGuestSession session = guestQrService.resolve(rawSessionToken);

        Order order = orderRepository
                .findForUpdateByOrderPublicId(orderPublicId)
                .orElseThrow(
                        () -> new BusinessException(
                                ErrorCode.ORDER_NOT_FOUND
                        )
                );

        guestOrderService.requireGuestOwnership(
                order,
                session.guestSessionId()
        );

        if (order.getStatus() != OrderStatus.PLACED) {
            throw new BusinessException(
                    ErrorCode.ORDER_CANNOT_CANCEL
            );
        }

        OrderTransition transition = refundAndTransition(
                order,
                OrderStatus.CANCELED,
                OrderActorType.GUEST,
                session.guestSessionId(),
                reason,
                RefundRequesterType.GUEST
        );

        flushAndPublish(
                order,
                transition
        );

        return OrderResponse.from(order);
    }

    @Transactional(noRollbackFor = RefundProcessingException.class)
    public OrderResponse cancelByCustomer(
            User user,
            String orderPublicId,
            String reason
    ) {
        Order order = orderRepository
                .findForUpdateByOrderPublicId(orderPublicId)
                .orElseThrow(
                        () -> new BusinessException(
                                ErrorCode.ORDER_NOT_FOUND
                        )
                );

        if (!order.belongsToUser(user.getId())) {
            throw new BusinessException(
                    ErrorCode.ORDER_ACCESS_DENIED
            );
        }

        if (order.getStatus() != OrderStatus.PLACED) {
            throw new BusinessException(
                    ErrorCode.ORDER_CANNOT_CANCEL
            );
        }

        OrderTransition transition = refundAndTransition(
                order,
                OrderStatus.CANCELED,
                OrderActorType.CUSTOMER,
                user.getId(),
                reason,
                RefundRequesterType.CUSTOMER
        );

        flushAndPublish(
                order,
                transition
        );

        return OrderResponse.from(order);
    }

    @Transactional(readOnly = true)
    public List<OrderResponse> findSellerOrders(
            User user,
            Long storeId,
            OrderStatus status
    ) {
        requireStoreMember(
                user.getId(),
                storeId
        );

        List<Order> orders = status == null
                ? orderRepository
                .findAllByStoreIdOrderByCreatedAtAsc(storeId)
                : orderRepository
                .findAllByStoreIdAndStatusOrderByCreatedAtAsc(
                        storeId,
                        status
                );

        return orders.stream()
                .map(OrderResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public OrderResponse findSellerOrder(
            User user,
            Long storeId,
            String orderPublicId
    ) {
        requireStoreMember(
                user.getId(),
                storeId
        );

        Order order = orderRepository
                .findDetailedByOrderPublicIdAndStoreId(
                        orderPublicId,
                        storeId
                )
                .orElseThrow(
                        () -> new BusinessException(
                                ErrorCode.ORDER_NOT_FOUND
                        )
                );

        return OrderResponse.from(order);
    }

    @Transactional(readOnly = true)
    public OrderSyncResponse syncSellerOrder(
            User user,
            Long storeId,
            String orderPublicId,
            long knownVersion
    ) {
        requireStoreMember(
                user.getId(),
                storeId
        );

        Order order = orderRepository
                .findDetailedByOrderPublicIdAndStoreId(
                        orderPublicId,
                        storeId
                )
                .orElseThrow(
                        () -> new BusinessException(
                                ErrorCode.ORDER_NOT_FOUND
                        )
                );

        return OrderSyncResponse.from(
                order,
                knownVersion
        );
    }

    @Transactional(noRollbackFor = RefundProcessingException.class)
    public OrderResponse transitionBySeller(
            User user,
            Long storeId,
            String orderPublicId,
            OrderStatus targetStatus,
            String reason
    ) {
        requireStoreMember(
                user.getId(),
                storeId
        );

        Order order = lockedSellerOrder(
                storeId,
                orderPublicId
        );

        if (targetStatus == OrderStatus.REJECTED) {
            if (order.getStatus() != OrderStatus.PLACED) {
                throw new BusinessException(
                        ErrorCode.INVALID_ORDER_STATUS
                );
            }

            OrderTransition transition = refundAndTransition(
                    order,
                    OrderStatus.REJECTED,
                    OrderActorType.SELLER,
                    user.getId(),
                    reason,
                    RefundRequesterType.SELLER
            );

            flushAndPublish(
                    order,
                    transition
            );
        } else {
            Instant transitionedAt = Instant.now();

            OrderTransition transition = order.transitionTo(
                    targetStatus,
                    OrderActorType.SELLER,
                    user.getId(),
                    reason,
                    transitionedAt
            );

            if (targetStatus == OrderStatus.COMPLETED) {
                rewardCompletedCustomerOrder(
                        order,
                        transitionedAt
                );
            }

            flushAndPublish(
                    order,
                    transition
            );
        }

        return OrderResponse.from(order);
    }

    private void rewardCompletedCustomerOrder(
            Order order,
            Instant completedAt
    ) {
        if (order.getUser() == null) {
            return;
        }

        paymentRepository
                .findForUpdateByOrderId(order.getId())
                .filter(payment -> payment.getStatus() == PaymentStatus.PAID)
                .ifPresent(payment -> customerPointService.rewardPayment(
                        payment,
                        completedAt
                ));
    }

    private Order lockedSellerOrder(
            Long storeId,
            String orderPublicId
    ) {
        Order order = orderRepository
                .findForUpdateByOrderPublicId(orderPublicId)
                .orElseThrow(
                        () -> new BusinessException(
                                ErrorCode.ORDER_NOT_FOUND
                        )
                );

        if (!order.getStore().getId().equals(storeId)) {
            throw new BusinessException(
                    ErrorCode.ORDER_NOT_FOUND
            );
        }

        return order;
    }

    private OrderTransition refundAndTransition(
            Order order,
            OrderStatus targetStatus,
            OrderActorType actorType,
            Long actorId,
            String reason,
            RefundRequesterType requesterType
    ) {
        Payment payment = paymentRepository
                .findByOrderId(order.getId())
                .orElseThrow(
                        () -> new BusinessException(
                                ErrorCode.PAYMENT_NOT_FOUND
                        )
                );

        if (payment.getStatus() != PaymentStatus.PAID
                || payment.getApprovedAmount() == null) {
            throw new BusinessException(
                    ErrorCode.ORDER_CANNOT_CANCEL
            );
        }

        Instant requestedAt = Instant.now();

        Refund refund = Refund.requested(
                payment,
                payment.getApprovedAmount(),
                reason,
                requesterType,
                actorId,
                requestedAt
        );

        refund.markProcessing();
        payment.addRefund(refund);

        PaymentCancellationCommand command =
                new PaymentCancellationCommand(
                        payment.getProviderPaymentKey(),
                        refund.getAmount(),
                        reason
                );

        PaymentProvider paymentProvider =
                paymentProviderRegistry.get(
                        payment.getProvider()
                );

        PaymentCancellationResult result =
                paymentProvider.cancel(command);

        String requestPayload =
                "{\"amount\":" + refund.getAmount() + "}";

        Instant processedAt = Instant.now();

        if (!result.success()) {
            refund.markFailed(
                    result.failureCode(),
                    result.failureMessage()
            );

            payment.addTransaction(
                    PaymentTransaction.failed(
                            payment,
                            PaymentTransactionType.CANCEL,
                            requestPayload,
                            "{\"success\":false}",
                            result.failureCode(),
                            result.failureMessage(),
                            processedAt
                    )
            );

            throw new RefundProcessingException(
                    result.failureMessage()
            );
        }

        refund.markSucceeded(
                result.providerRefundKey(),
                processedAt
        );

        payment.markCanceled(processedAt);
        customerPointService.reclaimRefund(payment, refund, processedAt);

        payment.addTransaction(
                PaymentTransaction.succeeded(
                        payment,
                        PaymentTransactionType.CANCEL,
                        requestPayload,
                        "{\"success\":true}",
                        processedAt
                )
        );

        return order.transitionTo(
                targetStatus,
                actorType,
                actorId,
                reason,
                processedAt
        );
    }

    private void flushAndPublish(
            Order order,
            OrderTransition transition
    ) {
        orderRepository.flush();

        orderEventPublisher.publish(
                order,
                transition
        );
    }

    private void requireStoreMember(
            Long userId,
            Long storeId
    ) {
        storeAuthorizationService.requireAnyRole(
                userId,
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
    }
}