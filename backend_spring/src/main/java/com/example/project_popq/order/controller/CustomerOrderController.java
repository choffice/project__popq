package com.example.project_popq.order.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.order.dto.CreateCustomerOrderRequest;
import com.example.project_popq.order.dto.OrderCommandRequest;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.dto.OrderSyncResponse;
import com.example.project_popq.order.service.CustomerOrderService;
import com.example.project_popq.order.service.OrderCommandService;
import com.example.project_popq.payment.dto.ConfirmPaymentRequest;
import com.example.project_popq.payment.dto.KakaoPaymentPrepareRequest;
import com.example.project_popq.payment.dto.KakaoPaymentPrepareResponse;
import com.example.project_popq.payment.dto.PaymentResponse;
import com.example.project_popq.payment.service.KakaoPaymentService;
import com.example.project_popq.payment.service.PaymentService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/customer/orders")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerOrderController {

    private final CurrentUserService currentUserService;
    private final CustomerOrderService customerOrderService;
    private final PaymentService paymentService;
    private final KakaoPaymentService kakaoPaymentService;
    private final OrderCommandService orderCommandService;

    @PostMapping("/stores/{storeId}")
    public ResponseEntity<ApiResponse<OrderResponse>> create(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @Valid @RequestBody CreateCustomerOrderRequest request
    ) {
        OrderResponse created = customerOrderService.create(
                currentUserService.getRequired(jwt),
                storeId,
                request
        );

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(created));
    }

    @GetMapping
    public ApiResponse<List<OrderResponse>> findAll(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
                customerOrderService.findAll(
                        currentUserService.getRequired(jwt)
                )
        );
    }

    @GetMapping("/{orderPublicId}")
    public ApiResponse<OrderResponse> findOne(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String orderPublicId
    ) {
        return ApiResponse.success(
                customerOrderService.findOne(
                        currentUserService.getRequired(jwt),
                        orderPublicId
                )
        );
    }

    @GetMapping("/{orderPublicId}/sync")
    public ApiResponse<OrderSyncResponse> sync(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String orderPublicId,
            @RequestParam long knownVersion
    ) {
        return ApiResponse.success(
                customerOrderService.sync(
                        currentUserService.getRequired(jwt),
                        orderPublicId,
                        knownVersion
                )
        );
    }

    /**
     * 기존 토스페이먼츠 및 테스트 결제 승인 API입니다.
     *
     * 카카오페이는 이 API를 사용하지 않고
     * /payments/kakao/prepare와 추후 추가될
     * /payments/kakao/approve API를 사용합니다.
     */
    @PostMapping("/{orderPublicId}/payments")
    public ApiResponse<PaymentResponse> confirmPayment(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String orderPublicId,
            @Valid @RequestBody ConfirmPaymentRequest request
    ) {
        return ApiResponse.success(
                paymentService.confirmCustomer(
                        currentUserService.getRequired(jwt),
                        orderPublicId,
                        request
                )
        );
    }

    /**
     * 카카오페이 결제를 준비하고 결제창 이동 URL을 반환합니다.
     */
    @PostMapping(
            "/{orderPublicId}/payments/kakao/prepare"
    )
    public ApiResponse<KakaoPaymentPrepareResponse>
    prepareKakaoPayment(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String orderPublicId,
            @Valid @RequestBody
            KakaoPaymentPrepareRequest request
    ) {
        return ApiResponse.success(
                kakaoPaymentService.prepareCustomer(
                        currentUserService.getRequired(jwt),
                        orderPublicId,
                        request.idempotencyKey()
                )
        );
    }

    @PostMapping("/{orderPublicId}/cancel")
    public ApiResponse<OrderResponse> cancel(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable String orderPublicId,
            @Valid @RequestBody OrderCommandRequest request
    ) {
        return ApiResponse.success(
                orderCommandService.cancelByCustomer(
                        currentUserService.getRequired(jwt),
                        orderPublicId,
                        request.reasonOr("고객 주문 취소")
                )
        );
    }
}