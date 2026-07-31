package com.example.project_popq.payment.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderActorType;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderTransition;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.order.service.GuestOrderService;
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
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import com.example.project_popq.realtime.event.OrderDomainEventPublisher;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
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
    private final PaymentProvider paymentProvider;
    private final OrderDomainEventPublisher orderEventPublisher;

    @Transactional(noRollbackFor = PaymentProcessingException.class)
    public PaymentResponse confirm(
            String rawSessionToken,
            String orderPublicId,
            ConfirmPaymentRequest request
    ) {
        ResolvedGuestSession session = guestQrService.resolve(rawSessionToken);
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
        return confirmOwned(orderPublicId, request, null, user.getId());
    }

    private PaymentResponse confirmOwned(
            String orderPublicId,
            ConfirmPaymentRequest request,
            Long guestSessionId,
            Long userId
    ) {
        Payment replay = paymentRepository
                .findByIdempotencyKey(request.idempotencyKey())
                .orElse(null);
        if (replay != null) {
            validateReplay(
                    replay,
                    orderPublicId,
                    guestSessionId,
                    userId
            );
            if (replay.getStatus() == PaymentStatus.FAILED) {
                throw new PaymentProcessingException(
                        ErrorCode.PAYMENT_FAILED,
                        replay.getFailureMessage()
                );
            }
            return PaymentResponse.from(replay);
        }

        Order order = orderRepository.findForUpdateByOrderPublicId(orderPublicId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ORDER_NOT_FOUND));
        requireOwnership(order, guestSessionId, userId);

        if (paymentRepository.findByOrderId(order.getId()).isPresent()) {
            throw new BusinessException(ErrorCode.IDEMPOTENCY_CONFLICT);
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
            orderEventPublisher.publish(order, transition);
            throw new PaymentProcessingException(
                    ErrorCode.ORDER_EXPIRED,
                    ErrorCode.ORDER_EXPIRED.getMessage()
            );
        }
        if (order.getStatus() != OrderStatus.CREATED) {
            throw new BusinessException(ErrorCode.INVALID_ORDER_STATUS);
        }

        Payment payment = Payment.ready(
                order,
                PaymentProviderType.TEST,
                PaymentMethod.TEST,
                order.getTotalAmount(),
                request.idempotencyKey()
        );
        payment.markInProgress();
        paymentRepository.save(payment);

        PaymentApprovalCommand command = new PaymentApprovalCommand(
            orderPublicId,
            order.getTotalAmount(),
            request.paymentKey(),
            request.simulateFailure()
        );
        PaymentApprovalResult result = paymentProvider.approve(command);
        Instant processedAt = Instant.now();
        String requestPayload = "{\"orderPublicId\":\"" + orderPublicId
                + "\",\"amount\":" + order.getTotalAmount() + "}";

        if (!result.success()) {
            payment.markFailed(result.failureCode(), result.failureMessage());
            payment.addTransaction(PaymentTransaction.failed(
                    payment,
                    PaymentTransactionType.APPROVE,
                    requestPayload,
                    "{\"success\":false}",
                    result.failureCode(),
                    result.failureMessage(),
                    processedAt
            ));
            throw new PaymentProcessingException(
                    ErrorCode.PAYMENT_FAILED,
                    result.failureMessage()
            );
        }
        if (result.approvedAmount() != order.getTotalAmount()) {
            payment.markFailed(
                    "PAYMENT_AMOUNT_MISMATCH",
                    ErrorCode.PAYMENT_AMOUNT_MISMATCH.getMessage()
            );
            payment.addTransaction(PaymentTransaction.failed(
                    payment,
                    PaymentTransactionType.APPROVE,
                    requestPayload,
                    "{\"success\":true,\"amount\":"
                            + result.approvedAmount() + "}",
                    "PAYMENT_AMOUNT_MISMATCH",
                    ErrorCode.PAYMENT_AMOUNT_MISMATCH.getMessage(),
                    processedAt
            ));
            throw new PaymentProcessingException(
                    ErrorCode.PAYMENT_AMOUNT_MISMATCH,
                    ErrorCode.PAYMENT_AMOUNT_MISMATCH.getMessage()
            );
        }

        payment.markPaid(
                result.approvedAmount(),
                result.providerPaymentKey(),
                processedAt
        );
        payment.addTransaction(PaymentTransaction.succeeded(
                payment,
                PaymentTransactionType.APPROVE,
                requestPayload,
                "{\"success\":true,\"amount\":" + result.approvedAmount() + "}",
                processedAt
        ));
        OrderTransition transition = order.transitionTo(
                OrderStatus.PLACED,
                OrderActorType.SYSTEM,
                null,
                "결제 승인",
                processedAt
        );
        orderRepository.flush();
        orderEventPublisher.publish(order, transition);
        return PaymentResponse.from(payment);
    }

    private void validateReplay(
            Payment payment,
            String orderPublicId,
            Long guestSessionId,
            Long userId
    ) {
        if (!payment.getOrder().getOrderPublicId().equals(orderPublicId)) {
            throw new BusinessException(ErrorCode.IDEMPOTENCY_CONFLICT);
        }
        requireOwnership(payment.getOrder(), guestSessionId, userId);
    }

    private void requireOwnership(
            Order order,
            Long guestSessionId,
            Long userId
    ) {
        if (guestSessionId != null) {
            guestOrderService.requireGuestOwnership(order, guestSessionId);
            return;
        }
        if (userId == null || !order.belongsToUser(userId)) {
            throw new BusinessException(ErrorCode.ORDER_ACCESS_DENIED);
        }
    }
}
