package com.example.project_popq.payment.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.dto.CustomerPaymentSummaryResponse;
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.user.domain.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomerPaymentQueryService {

    private final PaymentRepository paymentRepository;

    @Transactional(readOnly = true)
    public CustomerPaymentSummaryResponse findSummary(
            User user,
            String orderPublicId
    ) {
        Payment payment = paymentRepository
                .findDetailedByOrderOrderPublicId(orderPublicId)
                .orElseThrow(
                        () -> new BusinessException(
                                ErrorCode.PAYMENT_NOT_FOUND
                        )
                );

        if (!payment.getOrder().belongsToUser(user.getId())) {
            throw new BusinessException(
                    ErrorCode.ORDER_ACCESS_DENIED
            );
        }

        return CustomerPaymentSummaryResponse.from(payment);
    }
}
