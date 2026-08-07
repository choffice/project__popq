package com.example.project_popq.payment.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderActorType;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderTransition;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.order.service.GuestOrderService;
import com.example.project_popq.payment.config.PaymentProperties;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentMethod;
import com.example.project_popq.payment.domain.PaymentProviderType;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.payment.domain.PaymentTransaction;
import com.example.project_popq.payment.domain.PaymentTransactionType;
import com.example.project_popq.payment.dto.ConfirmPaymentRequest;
import com.example.project_popq.payment.dto.PaymentResponse;
import com.example.project_popq.payment.provider.PaymentApprovalCommand;
import com.example.project_popq.payment.provider.PaymentApprovalResult;
import com.example.project_popq.payment.provider.PaymentProvider;
import com.example.project_popq.payment.provider.PaymentProviderRegistry;
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import com.example.project_popq.realtime.event.OrderDomainEventPublisher;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PaymentService {

    private final GuestQrService guestQrService;
    private final GuestOrderService guestOrderService;
    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;
    private final PaymentProviderRegistry paymentProviderRegistry;
    private final OrderDomainEventPublisher orderEventPublisher;
    private final PaymentProperties paymentProperties;

    @Transactional(noRollbackFor = PaymentProcessingException.class)
    public PaymentResponse confirm(
        String rawSessionToken,
        String orderPublicId,
        ConfirmPaymentRequest request
    ) {
        ResolvedGuestSession session =
            guestQrService.resolve(rawSessionToken);

        return confirmOwned(
            orderPublicId,
            request,
            session.guestSessionId(),
            null
        );
    }

    @Transactional(noRollbackFor = PaymentProcessingException.class)
    public PaymentResponse confirmCustomer(
        User user,
        String orderPublicId,
        ConfirmPaymentRequest request
    ) {
        return confirmOwned(
            orderPublicId,
            request,
            null,
            user.getId()
        );
    }

    private PaymentResponse confirmOwned(
        String orderPublicId,
        ConfirmPaymentRequest request,
        Long guestSessionId,
        Long userId
    ) {
        Payment replay = paymentRepository
            .findForUpdateByIdempotencyKey(
                request.idempotencyKey()
            )
            .orElse(null);

        if (replay != null) {
            validateReplay(
                replay,
                orderPublicId,
                guestSessionId,
                userId
            );

            return replayOrResume(
                replay,
                request
            );
        }

        Order order = orderRepository
            .findForUpdateByOrderPublicId(orderPublicId)
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.ORDER_NOT_FOUND
                )
            );

        requireOwnership(
            order,
            guestSessionId,
            userId
        );

        Payment orderPayment = paymentRepository
            .findByOrderId(order.getId())
            .orElse(null);

        if (orderPayment != null) {
            if (!orderPayment
                .getIdempotencyKey()
                .equals(request.idempotencyKey())) {
                throw new BusinessException(
                    ErrorCode.IDEMPOTENCY_CONFLICT
                );
            }

            return replayOrResume(
                orderPayment,
                request
            );
        }

        Instant now = Instant.now();

        if (order.isPaymentExpired(now)) {
            OrderTransition transition = order.transitionTo(
                OrderStatus.EXPIRED,
                OrderActorType.SYSTEM,
                null,
                "결제 가능 시간 만료",
                now
            );

            orderRepository.flush();

            orderEventPublisher.publish(
                order,
                transition
            );

            throw new PaymentProcessingException(
                ErrorCode.ORDER_EXPIRED,
                ErrorCode.ORDER_EXPIRED.getMessage()
            );
        }

        if (order.getStatus() != OrderStatus.CREATED) {
            throw new BusinessException(
                ErrorCode.INVALID_ORDER_STATUS
            );
        }

        PaymentProviderType providerType =
            paymentProperties.provider();

        PaymentMethod paymentMethod =
            resolveLegacyPaymentMethod(providerType);

        Payment payment = Payment.ready(
            order,
            providerType,
            paymentMethod,
            order.getTotalAmount(),
            request.idempotencyKey()
        );

        payment.markInProgress(
            request.paymentKey()
        );

        paymentRepository.save(payment);

        return approve(
            payment,
            order,
            request
        );
    }

    private PaymentMethod resolveLegacyPaymentMethod(
        PaymentProviderType providerType
    ) {
        return switch (providerType) {
            case TEST -> PaymentMethod.TEST;
            case TOSS_PAYMENTS -> PaymentMethod.CARD;
        };
    }

    private PaymentResponse replayOrResume(
        Payment payment,
        ConfirmPaymentRequest request
    ) {
        if (payment.getStatus() == PaymentStatus.FAILED) {
            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                payment.getFailureMessage()
            );
        }

        if (payment.getStatus()
            != PaymentStatus.IN_PROGRESS) {
            return PaymentResponse.from(payment);
        }

        if (!Objects.equals(
            payment.getProviderPaymentKey(),
            request.paymentKey()
        )) {
            throw new BusinessException(
                ErrorCode.IDEMPOTENCY_CONFLICT
            );
        }

        return approve(
            payment,
            payment.getOrder(),
            request
        );
    }

    private PaymentResponse approve(
        Payment payment,
        Order order,
        ConfirmPaymentRequest request
    ) {
        PaymentApprovalCommand command =
            new PaymentApprovalCommand(
                order.getOrderPublicId(),
                order.getTotalAmount(),
                request.paymentKey(),
                request.idempotencyKey(),
                request.simulateFailure()
            );

        PaymentProvider paymentProvider =
            paymentProviderRegistry.get(
                payment.getProvider()
            );

        PaymentApprovalResult result =
            paymentProvider.approve(command);

        Instant processedAt = Instant.now();

        String requestPayload =
            "{\"orderPublicId\":\""
                + order.getOrderPublicId()
                + "\",\"amount\":"
                + order.getTotalAmount()
                + "}";

        if (!result.success()) {
            if (!"TOSS_COMMUNICATION_ERROR".equals(
                result.failureCode()
            )) {
                payment.markFailed(
                    result.failureCode(),
                    result.failureMessage()
                );
            }

            payment.addTransaction(
                PaymentTransaction.failed(
                    payment,
                    PaymentTransactionType.APPROVE,
                    requestPayload,
                    "{\"success\":false}",
                    result.failureCode(),
                    result.failureMessage(),
                    processedAt
                )
            );

            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                result.failureMessage()
            );
        }

        if (result.approvedAmount()
            != order.getTotalAmount()) {
            payment.markFailed(
                "PAYMENT_AMOUNT_MISMATCH",
                ErrorCode
                    .PAYMENT_AMOUNT_MISMATCH
                    .getMessage()
            );

            payment.addTransaction(
                PaymentTransaction.failed(
                    payment,
                    PaymentTransactionType.APPROVE,
                    requestPayload,
                    "{\"success\":true,\"amount\":"
                        + result.approvedAmount()
                        + "}",
                    "PAYMENT_AMOUNT_MISMATCH",
                    ErrorCode
                        .PAYMENT_AMOUNT_MISMATCH
                        .getMessage(),
                    processedAt
                )
            );

            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_AMOUNT_MISMATCH,
                ErrorCode
                    .PAYMENT_AMOUNT_MISMATCH
                    .getMessage()
            );
        }

        payment.markPaid(
            result.approvedAmount(),
            result.providerPaymentKey(),
            processedAt
        );

        payment.addTransaction(
            PaymentTransaction.succeeded(
                payment,
                PaymentTransactionType.APPROVE,
                requestPayload,
                "{\"success\":true,\"amount\":"
                    + result.approvedAmount()
                    + "}",
                processedAt
            )
        );

        OrderTransition transition = order.transitionTo(
            OrderStatus.PLACED,
            OrderActorType.SYSTEM,
            null,
            "결제 승인",
            processedAt
        );

        orderRepository.flush();

        orderEventPublisher.publish(
            order,
            transition
        );

        return PaymentResponse.from(payment);
    }

    private void validateReplay(
        Payment payment,
        String orderPublicId,
        Long guestSessionId,
        Long userId
    ) {
        if (!payment
            .getOrder()
            .getOrderPublicId()
            .equals(orderPublicId)) {
            throw new BusinessException(
                ErrorCode.IDEMPOTENCY_CONFLICT
            );
        }

        requireOwnership(
            payment.getOrder(),
            guestSessionId,
            userId
        );
    }

    private void requireOwnership(
        Order order,
        Long guestSessionId,
        Long userId
    ) {
        if (guestSessionId != null) {
            guestOrderService.requireGuestOwnership(
                order,
                guestSessionId
            );

            return;
        }

        if (userId == null
            || !order.belongsToUser(userId)) {
            throw new BusinessException(
                ErrorCode.ORDER_ACCESS_DENIED
            );
        }
    }
}