package com.example.project_popq.payment.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;

public class PaymentProcessingException extends BusinessException {

    public PaymentProcessingException(ErrorCode errorCode, String message) {
        super(errorCode, message);
    }
}
