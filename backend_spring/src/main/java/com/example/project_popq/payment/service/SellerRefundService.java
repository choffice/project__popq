package com.example.project_popq.payment.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.payment.domain.PaymentTransaction;
import com.example.project_popq.payment.domain.PaymentTransactionType;
import com.example.project_popq.payment.domain.Refund;
import com.example.project_popq.payment.domain.RefundRequesterType;
import com.example.project_popq.payment.dto.CreateSellerRefundRequest;
import com.example.project_popq.payment.dto.SellerPaymentSummaryResponse;
import com.example.project_popq.payment.provider.PaymentCancellationCommand;
import com.example.project_popq.payment.provider.PaymentCancellationResult;
import com.example.project_popq.payment.provider.PaymentProvider;
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SellerRefundService {

    private final StoreAuthorizationService storeAuthorizationService;
    private final OrderRepository orderRepository;
    private final PaymentRepository paymentRepository;
    private final PaymentProvider paymentProvider;

    @Transactional(readOnly = true)
    public SellerPaymentSummaryResponse findSummary(
            User user,
            Long storeId,
            String orderPublicId
    ) {
        requireStoreMember(user, storeId);
        Payment payment = paymentRepository
                .findByOrderOrderPublicIdAndOrderStoreId(orderPublicId, storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.PAYMENT_NOT_FOUND));
        return SellerPaymentSummaryResponse.from(payment);
    }

    @Transactional(noRollbackFor = RefundProcessingException.class)
    public SellerPaymentSummaryResponse refundCompletedOrder(
            User user,
            Long storeId,
            String orderPublicId,
            CreateSellerRefundRequest request
    ) {
        requireRefundManager(user, storeId);
        Order order = orderRepository.findForUpdateByOrderPublicId(orderPublicId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ORDER_NOT_FOUND));
        if (!order.getStore().getId().equals(storeId)) {
            throw new BusinessException(ErrorCode.ORDER_NOT_FOUND);
        }
        if (order.getStatus() != OrderStatus.COMPLETED) {
            throw new BusinessException(ErrorCode.REFUND_NOT_ALLOWED);
        }

        Payment payment = paymentRepository.findForUpdateByOrderId(order.getId())
                .orElseThrow(() -> new BusinessException(ErrorCode.PAYMENT_NOT_FOUND));
        if (payment.getStatus() != PaymentStatus.PAID
                || payment.getApprovedAmount() == null) {
            throw new BusinessException(ErrorCode.REFUND_NOT_ALLOWED);
        }
        if (request.amount() != payment.getApprovedAmount()) {
            throw new BusinessException(ErrorCode.INVALID_REFUND_AMOUNT);
        }

        String reason = request.reason().trim();
        Refund refund = Refund.requested(
                payment,
                request.amount(),
                reason,
                RefundRequesterType.SELLER,
                user.getId(),
                Instant.now()
        );
        refund.markProcessing();
        payment.addRefund(refund);

        PaymentCancellationResult result = paymentProvider.cancel(
                new PaymentCancellationCommand(
                        payment.getProviderPaymentKey(),
                        refund.getAmount(),
                        reason
                )
        );
        String requestPayload = "{\"amount\":" + refund.getAmount() + "}";
        Instant processedAt = Instant.now();
        if (!result.success()) {
            refund.markFailed(result.failureCode(), result.failureMessage());
            payment.addTransaction(PaymentTransaction.failed(
                    payment,
                    PaymentTransactionType.CANCEL,
                    requestPayload,
                    "{\"success\":false}",
                    result.failureCode(),
                    result.failureMessage(),
                    processedAt
            ));
            paymentRepository.flush();
            throw new RefundProcessingException(result.failureMessage());
        }

        refund.markSucceeded(result.providerRefundKey(), processedAt);
        payment.markRefunded(processedAt);
        payment.addTransaction(PaymentTransaction.succeeded(
                payment,
                PaymentTransactionType.CANCEL,
                requestPayload,
                "{\"success\":true}",
                processedAt
        ));
        paymentRepository.flush();
        return SellerPaymentSummaryResponse.from(payment);
    }

    private void requireStoreMember(User user, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
    }

    private void requireRefundManager(User user, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER
        );
    }
}
