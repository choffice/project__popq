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
import com.example.project_popq.payment.provider.PaymentLookupResult;
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

    @Transactional(noRollbackFor = PaymentProcessingException.class)
    public PaymentResponse recoverCustomer(
        User user,
        String orderPublicId
    ) {
        Order order = orderRepository
            .findForUpdateByOrderPublicId(orderPublicId)
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.ORDER_NOT_FOUND
                )
            );

        requireOwnership(
            order,
            null,
            user.getId()
        );

        Payment payment = paymentRepository
            .findForUpdateByOrderId(order.getId())
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.PAYMENT_NOT_FOUND
                )
            );

        if (payment.getStatus() == PaymentStatus.PAID) {
            ensureOrderPlacedAfterPayment(
                order,
                Instant.now(),
                "결제 상태 복구"
            );

            return PaymentResponse.from(payment);
        }

        if (payment.getStatus()
            != PaymentStatus.IN_PROGRESS) {
            return PaymentResponse.from(payment);
        }

        reconcileWithProvider(
            payment,
            order
        );

        return PaymentResponse.from(payment);
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
            .findForUpdateByOrderId(order.getId())
            .orElse(null);

        if (orderPayment != null) {
            if (orderPayment.getStatus()
                == PaymentStatus.PAID) {
                ensureOrderPlacedAfterPayment(
                    order,
                    Instant.now(),
                    "결제 상태 복구"
                );

                return PaymentResponse.from(orderPayment);
            }

            if (orderPayment.getStatus()
                == PaymentStatus.FAILED) {
                ensureOrderPayable(order);
                validateFailedPaymentRetry(
                    orderPayment,
                    request
                );

                orderPayment.restartAfterFailure(
                    request.idempotencyKey(),
                    request.paymentKey()
                );

                return approve(
                    orderPayment,
                    order,
                    request
                );
            }

            if (orderPayment.getStatus()
                    == PaymentStatus.CANCELED
                || orderPayment.getStatus()
                    == PaymentStatus.PARTIALLY_REFUNDED
                || orderPayment.getStatus()
                    == PaymentStatus.REFUNDED) {
                throw new BusinessException(
                    ErrorCode.INVALID_ORDER_STATUS
                );
            }

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

        ensureOrderPayable(order);

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
        if (payment.getStatus() == PaymentStatus.PAID) {
            ensureOrderPlacedAfterPayment(
                payment.getOrder(),
                Instant.now(),
                "결제 상태 복구"
            );

            return PaymentResponse.from(payment);
        }

        if (payment.getStatus() == PaymentStatus.FAILED) {
            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                failureMessageOrDefault(payment)
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

        LookupOutcome lookupOutcome = reconcileWithProvider(
            payment,
            payment.getOrder()
        );

        if (lookupOutcome == LookupOutcome.PAID) {
            return PaymentResponse.from(payment);
        }

        if (lookupOutcome
            == LookupOutcome.TERMINAL_FAILURE) {
            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                failureMessageOrDefault(payment)
            );
        }

        if (lookupOutcome == LookupOutcome.BLOCKED) {
            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                failureMessageOrDefault(payment)
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
            if (isUncertainApprovalFailure(
                result.failureCode()
            )) {
                payment.markUncertain(
                    result.failureCode(),
                    result.failureMessage()
                );
            } else {
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
            payment.markUncertain(
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

        if (request.paymentKey() != null
            && result.providerPaymentKey() != null
            && !Objects.equals(
                request.paymentKey(),
                result.providerPaymentKey()
            )) {
            payment.markUncertain(
                "PAYMENT_KEY_MISMATCH",
                "결제 승인 결과의 paymentKey가 요청과 일치하지 않습니다."
            );

            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                payment.getFailureMessage()
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

        ensureOrderPlacedAfterPayment(
            order,
            processedAt,
            "결제 승인"
        );

        return PaymentResponse.from(payment);
    }

    private LookupOutcome reconcileWithProvider(
        Payment payment,
        Order order
    ) {
        PaymentProvider paymentProvider =
            paymentProviderRegistry.get(
                payment.getProvider()
            );

        PaymentLookupResult lookupResult =
            paymentProvider.lookup(
                payment.getProviderPaymentKey()
            );

        if (lookupResult == null) {
            return LookupOutcome.UNSUPPORTED;
        }

        if (!lookupResult.success()) {
            if ("PAYMENT_LOOKUP_NOT_SUPPORTED".equals(
                lookupResult.failureCode()
            )) {
                return LookupOutcome.UNSUPPORTED;
            }

            payment.markUncertain(
                lookupResult.failureCode(),
                lookupResult.failureMessage()
            );

            return LookupOutcome.SAFE_TO_RETRY_APPROVAL;
        }

        if (!isLookupIdentityValid(
            payment,
            order,
            lookupResult
        )) {
            payment.markUncertain(
                "PAYMENT_RECOVERY_MISMATCH",
                "결제 조회 정보가 현재 주문과 일치하지 않아 자동 복구를 중단했습니다."
            );

            return LookupOutcome.BLOCKED;
        }

        Instant now = Instant.now();

        return switch (lookupResult.status()) {
            case PAID -> {
                payment.markPaid(
                    lookupResult.totalAmount(),
                    lookupResult.providerPaymentKey(),
                    lookupResult.approvedAt() == null
                        ? now
                        : lookupResult.approvedAt()
                );

                ensureOrderPlacedAfterPayment(
                    order,
                    now,
                    "결제 상태 복구"
                );

                yield LookupOutcome.PAID;
            }
            case CANCELED -> {
                payment.markFailed(
                    "PROVIDER_PAYMENT_CANCELED",
                    "토스페이먼츠에서 결제가 취소된 상태입니다. 새 결제를 다시 진행해주세요."
                );

                yield LookupOutcome.TERMINAL_FAILURE;
            }
            case FAILED -> {
                payment.markFailed(
                    "PROVIDER_PAYMENT_FAILED",
                    "토스페이먼츠에서 결제 승인 실패가 확인되었습니다."
                );

                yield LookupOutcome.TERMINAL_FAILURE;
            }
            case EXPIRED -> {
                payment.markFailed(
                    "PROVIDER_PAYMENT_EXPIRED",
                    "토스페이먼츠 결제 인증이 만료되었습니다. 새 결제를 다시 진행해주세요."
                );

                yield LookupOutcome.TERMINAL_FAILURE;
            }
            case PARTIALLY_REFUNDED -> {
                payment.markUncertain(
                    "PROVIDER_PAYMENT_PARTIALLY_REFUNDED",
                    "결제가 부분 취소된 상태라 자동 재승인을 중단했습니다. 결제 내역을 확인해주세요."
                );

                yield LookupOutcome.BLOCKED;
            }
            case READY, IN_PROGRESS -> {
                payment.markUncertain(
                    "PROVIDER_PAYMENT_NOT_CONFIRMED",
                    "결제 승인이 아직 확정되지 않았습니다."
                );

                yield LookupOutcome.SAFE_TO_RETRY_APPROVAL;
            }
            case UNKNOWN -> {
                payment.markUncertain(
                    "PROVIDER_PAYMENT_STATUS_UNKNOWN",
                    "결제 상태를 자동으로 판단할 수 없어 재승인을 중단했습니다."
                );

                yield LookupOutcome.BLOCKED;
            }
        };
    }

    private boolean isLookupIdentityValid(
        Payment payment,
        Order order,
        PaymentLookupResult lookupResult
    ) {
        if (!Objects.equals(
            payment.getProviderPaymentKey(),
            lookupResult.providerPaymentKey()
        )) {
            return false;
        }

        if (!Objects.equals(
            order.getOrderPublicId(),
            lookupResult.orderPublicId()
        )) {
            return false;
        }

        return lookupResult.totalAmount() != null
            && lookupResult.totalAmount()
                == order.getTotalAmount();
    }

    private void validateFailedPaymentRetry(
        Payment payment,
        ConfirmPaymentRequest request
    ) {
        if (Objects.equals(
            payment.getIdempotencyKey(),
            request.idempotencyKey()
        )) {
            throw new BusinessException(
                ErrorCode.IDEMPOTENCY_CONFLICT
            );
        }

        if (payment.getProvider()
            == PaymentProviderType.TOSS_PAYMENTS) {
            if (request.paymentKey() == null
                || request.paymentKey().isBlank()) {
                throw new BusinessException(
                    ErrorCode.INVALID_REQUEST
                );
            }

            if (Objects.equals(
                payment.getProviderPaymentKey(),
                request.paymentKey()
            )) {
                throw new BusinessException(
                    ErrorCode.IDEMPOTENCY_CONFLICT
                );
            }
        }
    }

    private void ensureOrderPayable(
        Order order
    ) {
        Instant now = Instant.now();

        if (order.isPaymentExpired(now)) {
            if (order.getStatus() == OrderStatus.CREATED) {
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
            }

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
    }

    private void ensureOrderPlacedAfterPayment(
        Order order,
        Instant occurredAt,
        String reason
    ) {
        if (order.getStatus() != OrderStatus.CREATED) {
            return;
        }

        OrderTransition transition = order.transitionTo(
            OrderStatus.PLACED,
            OrderActorType.SYSTEM,
            null,
            reason,
            occurredAt
        );

        orderRepository.flush();

        orderEventPublisher.publish(
            order,
            transition
        );
    }

    private boolean isUncertainApprovalFailure(
        String failureCode
    ) {
        return "TOSS_COMMUNICATION_ERROR".equals(failureCode)
            || "IDEMPOTENT_REQUEST_PROCESSING".equals(failureCode)
            || "TOSS_EMPTY_RESPONSE".equals(failureCode)
            || "TOSS_INVALID_RESPONSE".equals(failureCode);
    }

    private String failureMessageOrDefault(
        Payment payment
    ) {
        if (payment.getFailureMessage() == null
            || payment.getFailureMessage().isBlank()) {
            return ErrorCode.PAYMENT_FAILED.getMessage();
        }

        return payment.getFailureMessage();
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

    private enum LookupOutcome {
        PAID,
        TERMINAL_FAILURE,
        SAFE_TO_RETRY_APPROVAL,
        BLOCKED,
        UNSUPPORTED
    }
}
