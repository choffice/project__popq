package com.example.project_popq.order.controller;

import static com.example.project_popq.qr.controller.PublicQrController.GUEST_SESSION_COOKIE;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.order.dto.CreateGuestOrderRequest;
import com.example.project_popq.order.dto.OrderCommandRequest;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.dto.OrderSyncResponse;
import com.example.project_popq.order.service.GuestOrderService;
import com.example.project_popq.order.service.OrderCommandService;
import com.example.project_popq.payment.dto.ConfirmPaymentRequest;
import com.example.project_popq.payment.dto.PaymentResponse;
import com.example.project_popq.payment.service.PaymentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/qr/orders")
@RequiredArgsConstructor
public class GuestOrderController {

    private final GuestOrderService guestOrderService;
    private final PaymentService paymentService;
    private final OrderCommandService orderCommandService;

    @PostMapping
    public ResponseEntity<ApiResponse<OrderResponse>> create(
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String sessionToken,
            @Valid @RequestBody CreateGuestOrderRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(
                        guestOrderService.create(sessionToken, request)
                ));
    }

    @GetMapping("/{orderPublicId}")
    public ApiResponse<OrderResponse> get(
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String sessionToken,
            @PathVariable String orderPublicId
    ) {
        return ApiResponse.success(
                guestOrderService.get(sessionToken, orderPublicId)
        );
    }

    @GetMapping("/{orderPublicId}/sync")
    public ApiResponse<OrderSyncResponse> sync(
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String sessionToken,
            @PathVariable String orderPublicId,
            @RequestParam long knownVersion
    ) {
        return ApiResponse.success(
                guestOrderService.sync(
                        sessionToken,
                        orderPublicId,
                        knownVersion
                )
        );
    }

    @PostMapping("/{orderPublicId}/payments")
    public ApiResponse<PaymentResponse> confirmPayment(
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String sessionToken,
            @PathVariable String orderPublicId,
            @Valid @RequestBody ConfirmPaymentRequest request
    ) {
        return ApiResponse.success(
                paymentService.confirm(sessionToken, orderPublicId, request)
        );
    }

    @PostMapping("/{orderPublicId}/cancel")
    public ApiResponse<OrderResponse> cancel(
            @CookieValue(
                    name = GUEST_SESSION_COOKIE,
                    required = false
            ) String sessionToken,
            @PathVariable String orderPublicId,
            @Valid @RequestBody OrderCommandRequest request
    ) {
        return ApiResponse.success(
                orderCommandService.cancelByGuest(
                        sessionToken,
                        orderPublicId,
                        request.reasonOr("고객 주문 취소")
                )
        );
    }
}
