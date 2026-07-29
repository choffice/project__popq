package com.example.project_popq.payment.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;

public class RefundProcessingException extends BusinessException {

    public RefundProcessingException(String message) {
        super(ErrorCode.REFUND_FAILED, message);
    }
}
