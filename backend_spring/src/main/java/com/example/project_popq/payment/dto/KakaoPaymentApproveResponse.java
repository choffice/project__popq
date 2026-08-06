package com.example.project_popq.payment.dto;

import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentMethod;
import com.example.project_popq.payment.domain.PaymentProviderType;
import com.example.project_popq.payment.domain.PaymentStatus;
import java.time.Instant;

public record KakaoPaymentApproveResponse(

    Long paymentId,

    String orderPublicId,

    PaymentProviderType provider,

    PaymentMethod paymentMethod,

    PaymentStatus paymentStatus,

    OrderStatus orderStatus,

    Long approvedAmount,

    Instant approvedAt,

    boolean reused

) {

  public static KakaoPaymentApproveResponse from(
      Payment payment,
      boolean reused
  ) {
    return new KakaoPaymentApproveResponse(
        payment.getId(),
        payment.getOrder().getOrderPublicId(),
        payment.getProvider(),
        payment.getPaymentMethod(),
        payment.getStatus(),
        payment.getOrder().getStatus(),
        payment.getApprovedAmount(),
        payment.getApprovedAt(),
        reused
    );
  }
}