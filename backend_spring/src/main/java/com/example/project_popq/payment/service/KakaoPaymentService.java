package com.example.project_popq.payment.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderActorType;
import com.example.project_popq.order.domain.OrderItem;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderTransition;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.payment.config.KakaoPaymentProperties;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentMethod;
import com.example.project_popq.payment.domain.PaymentProviderType;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.payment.domain.PaymentTransaction;
import com.example.project_popq.payment.domain.PaymentTransactionType;
import com.example.project_popq.payment.dto.KakaoPaymentApproveRequest;
import com.example.project_popq.payment.dto.KakaoPaymentApproveResponse;
import com.example.project_popq.payment.dto.KakaoPaymentPrepareResponse;
import com.example.project_popq.payment.provider.KakaoPaymentClient;
import com.example.project_popq.payment.provider.KakaoPaymentClient.ApproveCommand;
import com.example.project_popq.payment.provider.KakaoPaymentClient.ApproveResult;
import com.example.project_popq.payment.provider.KakaoPaymentClient.PrepareCommand;
import com.example.project_popq.payment.provider.KakaoPaymentClient.PrepareResult;
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.realtime.event.OrderDomainEventPublisher;
import com.example.project_popq.user.domain.User;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class KakaoPaymentService {

    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;
    private final KakaoPaymentClient kakaoPaymentClient;
    private final KakaoPaymentProperties kakaoPaymentProperties;
    private final OrderDomainEventPublisher orderEventPublisher;

    @Transactional(
        noRollbackFor = PaymentProcessingException.class
    )
    public KakaoPaymentPrepareResponse prepareCustomer(
        User user,
        String orderPublicId,
        String idempotencyKey
    ) {
        requireConfiguration();

        Order order = orderRepository
            .findForUpdateByOrderPublicId(orderPublicId)
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.ORDER_NOT_FOUND
                )
            );

        requireOwnership(
            order,
            user
        );

        Instant now = Instant.now();

        Payment payment = paymentRepository
            .findByOrderId(order.getId())
            .orElse(null);

        if (payment != null) {
            validateExistingPayment(
                payment,
                idempotencyKey
            );

            if (payment.getStatus() == PaymentStatus.PAID) {
                return KakaoPaymentPrepareResponse.from(
                    payment,
                    true
                );
            }

            if (payment.hasReusablePreparation(now)) {
                return KakaoPaymentPrepareResponse.from(
                    payment,
                    true
                );
            }

            if (isFinishedPayment(payment)) {
                throw new BusinessException(
                    ErrorCode.INVALID_ORDER_STATUS
                );
            }
        }

        validatePayableOrder(
            order,
            now
        );

        if (payment == null) {
            requireUnusedIdempotencyKey(
                idempotencyKey
            );

            payment = Payment.ready(
                order,
                PaymentProviderType.KAKAO_PAY,
                PaymentMethod.KAKAO_PAY,
                order.getTotalAmount(),
                idempotencyKey
            );

            paymentRepository.saveAndFlush(payment);
        }

        PrepareCommand command = createPrepareCommand(
            order,
            user,
            payment
        );

        PrepareResult result =
            kakaoPaymentClient.prepare(command);

        if (!result.success()) {
            payment.markPreparationFailed(
                result.failureCode(),
                result.failureMessage()
            );

            paymentRepository.flush();

            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                result.failureMessage()
            );
        }

        String redirectUrl =
            resolveRedirectUrl(result);

        Instant providerExpiresAt =
            resolveProviderExpiresAt(
                order,
                now
            );

        payment.markPrepared(
            result.tid(),
            redirectUrl,
            providerExpiresAt
        );

        paymentRepository.flush();

        return KakaoPaymentPrepareResponse.from(
            payment,
            false
        );
    }

    @Transactional(
        noRollbackFor = PaymentProcessingException.class
    )
    public KakaoPaymentApproveResponse approveCustomer(
        User user,
        String orderPublicId,
        KakaoPaymentApproveRequest request
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
            user
        );

        Payment payment = paymentRepository
            .findForUpdateByOrderId(order.getId())
            .orElseThrow(
                () -> new BusinessException(
                    ErrorCode.PAYMENT_NOT_FOUND
                )
            );

        validateApproveTarget(
            payment,
            request
        );

        /*
         * 같은 승인 요청이 네트워크 문제 등으로 다시 들어오더라도,
         * 이미 PAID 상태이면 카카오페이에 중복 승인 요청을 보내지 않습니다.
         */
        if (payment.getStatus() == PaymentStatus.PAID) {
            return KakaoPaymentApproveResponse.from(
                payment,
                true
            );
        }

        if (payment.getStatus() == PaymentStatus.FAILED) {
            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                defaultFailureMessage(payment)
            );
        }

        if (payment.getStatus() != PaymentStatus.IN_PROGRESS) {
            throw new BusinessException(
                ErrorCode.INVALID_ORDER_STATUS,
                "현재 상태에서는 카카오페이 승인을 진행할 수 없습니다."
            );
        }

        if (order.getStatus() != OrderStatus.CREATED) {
            throw new BusinessException(
                ErrorCode.INVALID_ORDER_STATUS
            );
        }

        String tid = payment.getProviderPaymentKey();

        if (!hasText(tid)) {
            throw new BusinessException(
                ErrorCode.PAYMENT_FAILED,
                "카카오페이 결제 고유번호를 찾을 수 없습니다."
            );
        }

        String expectedPartnerUserId =
            createPartnerUserId(user);

        ApproveCommand command = new ApproveCommand(
            tid,
            order.getOrderPublicId(),
            expectedPartnerUserId,
            request.pgToken()
        );

        ApproveResult result =
            kakaoPaymentClient.approve(command);

        Instant processedAt = Instant.now();

        String requestPayload =
            createApproveRequestPayload(
                order,
                payment
            );

        if (!result.success()) {
            /*
             * 통신 오류는 카카오페이에서 승인이 완료됐지만
             * POPQ가 응답을 받지 못한 상황일 수 있습니다.
             *
             * 이 경우 FAILED로 확정하지 않고 IN_PROGRESS를 유지합니다.
             */
            if (!"KAKAO_COMMUNICATION_ERROR".equals(
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

            paymentRepository.flush();

            throw new PaymentProcessingException(
                ErrorCode.PAYMENT_FAILED,
                result.failureMessage()
            );
        }

        validateApproveResult(
            payment,
            order,
            expectedPartnerUserId,
            result,
            requestPayload,
            processedAt
        );

        payment.markPaid(
            result.approvedAmount(),
            result.tid(),
            processedAt
        );

        payment.addTransaction(
            PaymentTransaction.succeeded(
                payment,
                PaymentTransactionType.APPROVE,
                requestPayload,
                createApproveResponsePayload(result),
                processedAt
            )
        );

        OrderTransition transition = order.transitionTo(
            OrderStatus.PLACED,
            OrderActorType.SYSTEM,
            null,
            "카카오페이 결제 승인",
            processedAt
        );

        paymentRepository.flush();
        orderRepository.flush();

        orderEventPublisher.publish(
            order,
            transition
        );

        return KakaoPaymentApproveResponse.from(
            payment,
            false
        );
    }

    private void validateApproveTarget(
        Payment payment,
        KakaoPaymentApproveRequest request
    ) {
        if (!Objects.equals(
            payment.getId(),
            request.paymentId()
        )) {
            throw new BusinessException(
                ErrorCode.IDEMPOTENCY_CONFLICT,
                "주문과 결제 정보가 일치하지 않습니다."
            );
        }

        if (payment.getProvider()
            != PaymentProviderType.KAKAO_PAY) {
            throw new BusinessException(
                ErrorCode.IDEMPOTENCY_CONFLICT,
                "카카오페이로 준비된 결제가 아닙니다."
            );
        }
    }

    private void validateApproveResult(
        Payment payment,
        Order order,
        String expectedPartnerUserId,
        ApproveResult result,
        String requestPayload,
        Instant processedAt
    ) {
        String failureCode = null;
        String failureMessage = null;
        ErrorCode errorCode = ErrorCode.PAYMENT_FAILED;

        if (!Objects.equals(
            payment.getProviderPaymentKey(),
            result.tid()
        )) {
            failureCode =
                "KAKAO_TID_MISMATCH";

            failureMessage =
                "카카오페이 승인 결제번호가 준비된 결제와 일치하지 않습니다.";
        } else if (!Objects.equals(
            order.getOrderPublicId(),
            result.partnerOrderId()
        )) {
            failureCode =
                "KAKAO_ORDER_ID_MISMATCH";

            failureMessage =
                "카카오페이 승인 주문번호가 POPQ 주문번호와 일치하지 않습니다.";
        } else if (!Objects.equals(
            expectedPartnerUserId,
            result.partnerUserId()
        )) {
            failureCode =
                "KAKAO_USER_ID_MISMATCH";

            failureMessage =
                "카카오페이 승인 회원 정보가 POPQ 회원과 일치하지 않습니다.";
        } else if (result.approvedAmount()
            != order.getTotalAmount()) {
            failureCode =
                "PAYMENT_AMOUNT_MISMATCH";

            failureMessage =
                ErrorCode.PAYMENT_AMOUNT_MISMATCH
                    .getMessage();

            errorCode =
                ErrorCode.PAYMENT_AMOUNT_MISMATCH;
        }

        if (failureCode == null) {
            return;
        }

        /*
         * 카카오페이에서는 승인이 성공한 응답이므로 Payment를 FAILED로
         * 확정하지 않습니다. IN_PROGRESS 상태를 유지해 이후 조회·대사 또는
         * 취소 처리할 수 있도록 합니다.
         */
        payment.addTransaction(
            PaymentTransaction.failed(
                payment,
                PaymentTransactionType.APPROVE,
                requestPayload,
                createApproveResponsePayload(result),
                failureCode,
                failureMessage,
                processedAt
            )
        );

        paymentRepository.flush();

        throw new PaymentProcessingException(
            errorCode,
            failureMessage
        );
    }

    private String createApproveRequestPayload(
        Order order,
        Payment payment
    ) {
        return "{"
            + "\"orderPublicId\":\""
            + escapeJson(order.getOrderPublicId())
            + "\","
            + "\"paymentId\":"
            + payment.getId()
            + ","
            + "\"amount\":"
            + order.getTotalAmount()
            + "}";
    }

    private String createApproveResponsePayload(
        ApproveResult result
    ) {
        return "{"
            + "\"success\":true,"
            + "\"aid\":\""
            + escapeJson(result.aid())
            + "\","
            + "\"tid\":\""
            + escapeJson(result.tid())
            + "\","
            + "\"partnerOrderId\":\""
            + escapeJson(result.partnerOrderId())
            + "\","
            + "\"partnerUserId\":\""
            + escapeJson(result.partnerUserId())
            + "\","
            + "\"paymentMethodType\":\""
            + escapeJson(result.paymentMethodType())
            + "\","
            + "\"approvedAmount\":"
            + result.approvedAmount()
            + ","
            + "\"approvedAt\":\""
            + escapeJson(result.approvedAt())
            + "\""
            + "}";
    }

    private String defaultFailureMessage(
        Payment payment
    ) {
        return hasText(payment.getFailureMessage())
            ? payment.getFailureMessage()
            : ErrorCode.PAYMENT_FAILED.getMessage();
    }

    private void requireOwnership(
        Order order,
        User user
    ) {
        if (!order.belongsToUser(user.getId())) {
            throw new BusinessException(
                ErrorCode.ORDER_ACCESS_DENIED
            );
        }
    }

    private void validateExistingPayment(
        Payment payment,
        String idempotencyKey
    ) {
        if (payment.getProvider()
            != PaymentProviderType.KAKAO_PAY) {
            throw new BusinessException(
                ErrorCode.IDEMPOTENCY_CONFLICT,
                "이미 다른 결제수단으로 결제가 시작되었습니다."
            );
        }

        if (!payment
            .getIdempotencyKey()
            .equals(idempotencyKey)) {
            throw new BusinessException(
                ErrorCode.IDEMPOTENCY_CONFLICT
            );
        }
    }

    private boolean isFinishedPayment(
        Payment payment
    ) {
        return payment.getStatus()
            == PaymentStatus.CANCELED
            || payment.getStatus()
            == PaymentStatus.REFUNDED
            || payment.getStatus()
            == PaymentStatus.PARTIALLY_REFUNDED;
    }

    private void validatePayableOrder(
        Order order,
        Instant now
    ) {
        if (order.isPaymentExpired(now)) {
            OrderTransition transition =
                order.transitionTo(
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
                ErrorCode.ORDER_EXPIRED
                    .getMessage()
            );
        }

        if (order.getStatus()
            != OrderStatus.CREATED) {
            throw new BusinessException(
                ErrorCode.INVALID_ORDER_STATUS
            );
        }

        if (order.getTotalAmount() < 1) {
            throw new BusinessException(
                ErrorCode.INVALID_REQUEST,
                "결제 금액은 1원 이상이어야 합니다."
            );
        }
    }

    private void requireUnusedIdempotencyKey(
        String idempotencyKey
    ) {
        paymentRepository
            .findByIdempotencyKey(idempotencyKey)
            .ifPresent(
                existing -> {
                    throw new BusinessException(
                        ErrorCode.IDEMPOTENCY_CONFLICT
                    );
                }
            );
    }

    private PrepareCommand createPrepareCommand(
        Order order,
        User user,
        Payment payment
    ) {
        String approvalUrl =
            createCallbackUrl(
                kakaoPaymentProperties.approvalUrl(),
                order,
                payment
            );

        String cancelUrl =
            createCallbackUrl(
                kakaoPaymentProperties.cancelUrl(),
                order,
                payment
            );

        String failUrl =
            createCallbackUrl(
                kakaoPaymentProperties.failUrl(),
                order,
                payment
            );

        return new PrepareCommand(
            order.getOrderPublicId(),
            createPartnerUserId(user),
            createItemName(order.getItems()),
            calculateQuantity(order.getItems()),
            order.getTotalAmount(),
            0L,
            null,
            approvalUrl,
            cancelUrl,
            failUrl,
            kakaoPaymentProperties.redirectSchemeUrl()
        );
    }

    private String createPartnerUserId(
        User user
    ) {
        return "customer-" + user.getId();
    }

    private String createItemName(
        List<OrderItem> items
    ) {
        if (items.isEmpty()) {
            throw new BusinessException(
                ErrorCode.ORDER_ITEM_EMPTY
            );
        }

        String itemName =
            items.get(0).getProductNameSnapshot();

        if (items.size() > 1) {
            itemName = itemName
                + " 외 "
                + (items.size() - 1)
                + "건";
        }

        if (itemName.length() <= 100) {
            return itemName;
        }

        return itemName.substring(
            0,
            100
        );
    }

    private int calculateQuantity(
        List<OrderItem> items
    ) {
        long totalQuantity = items.stream()
            .mapToLong(OrderItem::getQuantity)
            .reduce(
                0L,
                Math::addExact
            );

        if (totalQuantity < 1
            || totalQuantity > Integer.MAX_VALUE) {
            throw new BusinessException(
                ErrorCode.INVALID_REQUEST,
                "카카오페이 상품 수량이 올바르지 않습니다."
            );
        }

        return (int) totalQuantity;
    }

    private String createCallbackUrl(
        String baseUrl,
        Order order,
        Payment payment
    ) {
        String separator =
            resolveQuerySeparator(baseUrl);

        return baseUrl
            + separator
            + "orderPublicId="
            + encode(order.getOrderPublicId())
            + "&paymentId="
            + payment.getId();
    }

    private String resolveQuerySeparator(
        String url
    ) {
        if (!url.contains("?")) {
            return "?";
        }

        if (url.endsWith("?")
            || url.endsWith("&")) {
            return "";
        }

        return "&";
    }

    private String resolveRedirectUrl(
        PrepareResult result
    ) {
        if (hasText(
            result.nextRedirectAppUrl()
        )) {
            return result.nextRedirectAppUrl();
        }

        if (hasText(
            result.nextRedirectMobileUrl()
        )) {
            return result.nextRedirectMobileUrl();
        }

        throw new PaymentProcessingException(
            ErrorCode.PAYMENT_FAILED,
            "카카오페이 결제 이동 URL을 받지 못했습니다."
        );
    }

    private Instant resolveProviderExpiresAt(
        Order order,
        Instant now
    ) {
        Instant readyExpiresAt = now.plus(
            kakaoPaymentProperties
                .resolvedReadyTtl()
        );

        Instant orderExpiresAt =
            order.getExpiresAt();

        return readyExpiresAt.isBefore(orderExpiresAt)
            ? readyExpiresAt
            : orderExpiresAt;
    }

    private void requireConfiguration() {
        if (!kakaoPaymentProperties
            .hasRequiredCallbackUrls()) {
            throw new BusinessException(
                ErrorCode.PAYMENT_FAILED,
                "카카오페이 성공·취소·실패 콜백 URL 설정이 필요합니다."
            );
        }
    }

    private String encode(
        String value
    ) {
        return URLEncoder.encode(
            value,
            StandardCharsets.UTF_8
        );
    }

    private String escapeJson(
        String value
    ) {
        if (value == null) {
            return "";
        }

        return value
            .replace("\\", "\\\\")
            .replace("\"", "\\\"");
    }

    private boolean hasText(
        String value
    ) {
        return value != null
            && !value.isBlank();
    }
}