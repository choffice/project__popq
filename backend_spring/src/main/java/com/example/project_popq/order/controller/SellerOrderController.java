package com.example.project_popq.order.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.dto.AcceptOrderRequest;
import com.example.project_popq.order.dto.OrderCommandRequest;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.dto.OrderSyncResponse;
import com.example.project_popq.order.service.OrderCommandService;
import com.example.project_popq.payment.dto.CreateSellerRefundRequest;
import com.example.project_popq.payment.dto.SellerPaymentSummaryResponse;
import com.example.project_popq.payment.service.SellerRefundService;
import jakarta.validation.Valid;
import java.util.List;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
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
@RequestMapping("/api/v1/seller/stores/{storeId}/orders")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerOrderController {

    private final CurrentUserService currentUserService;
    private final OrderCommandService orderCommandService;
    private final SellerRefundService sellerRefundService;

    @GetMapping
    public ApiResponse<List<OrderResponse>> findAll(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @RequestParam(required = false) OrderStatus status,
            @RequestParam(required = false) List<OrderStatus> statuses,
            @RequestParam(required = false) LocalDate date
    ) {
        return ApiResponse.success(
                orderCommandService.findSellerOrders(
                        currentUserService.getRequired(jwt),
                        storeId,
                        status,
                        statuses,
                        date
                )
        );
    }

    @GetMapping("/{orderPublicId}")
    public ApiResponse<OrderResponse> findOne(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId
    ) {
        return ApiResponse.success(
                orderCommandService.findSellerOrder(
                        currentUserService.getRequired(jwt),
                        storeId,
                        orderPublicId
                )
        );
    }

    @GetMapping("/{orderPublicId}/sync")
    public ApiResponse<OrderSyncResponse> sync(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId,
            @RequestParam long knownVersion
    ) {
        return ApiResponse.success(
                orderCommandService.syncSellerOrder(
                        currentUserService.getRequired(jwt),
                        storeId,
                        orderPublicId,
                        knownVersion
                )
        );
    }

    @PostMapping("/{orderPublicId}/accept")
    public ApiResponse<OrderResponse> accept(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId,
            @Valid @RequestBody AcceptOrderRequest request
    ) {
        return ApiResponse.success(
                orderCommandService.acceptBySeller(
                        currentUserService.getRequired(jwt),
                        storeId,
                        orderPublicId,
                        request.preparationMinutes(),
                        request.applyAsStoreDefault(),
                        request.reasonOr("주문 접수")
                )
        );
    }

    @PostMapping("/{orderPublicId}/reject")
    public ApiResponse<OrderResponse> reject(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId,
            @Valid @RequestBody OrderCommandRequest request
    ) {
        return transition(
                jwt,
                storeId,
                orderPublicId,
                OrderStatus.REJECTED,
                request.reasonOr("판매자 주문 거절")
        );
    }

    @PostMapping("/{orderPublicId}/prepare")
    public ApiResponse<OrderResponse> prepare(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId,
            @Valid @RequestBody OrderCommandRequest request
    ) {
        return transition(
                jwt,
                storeId,
                orderPublicId,
                OrderStatus.PREPARING,
                request.reasonOr("조리 시작")
        );
    }

    @PostMapping("/{orderPublicId}/ready")
    public ApiResponse<OrderResponse> ready(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId,
            @Valid @RequestBody OrderCommandRequest request
    ) {
        return transition(
                jwt,
                storeId,
                orderPublicId,
                OrderStatus.READY,
                request.reasonOr("상품 준비 완료")
        );
    }

    @PostMapping("/{orderPublicId}/complete")
    public ApiResponse<OrderResponse> complete(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId,
            @Valid @RequestBody OrderCommandRequest request
    ) {
        return transition(
                jwt,
                storeId,
                orderPublicId,
                OrderStatus.COMPLETED,
                request.reasonOr("주문 완료")
        );
    }

    @GetMapping("/{orderPublicId}/payment")
    public ApiResponse<SellerPaymentSummaryResponse> payment(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId
    ) {
        return ApiResponse.success(
                sellerRefundService.findSummary(
                        currentUserService.getRequired(jwt),
                        storeId,
                        orderPublicId
                )
        );
    }

    @PostMapping("/{orderPublicId}/refunds")
    public ApiResponse<SellerPaymentSummaryResponse> refund(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable String orderPublicId,
            @Valid @RequestBody CreateSellerRefundRequest request
    ) {
        return ApiResponse.success(
                sellerRefundService.refundCompletedOrder(
                        currentUserService.getRequired(jwt),
                        storeId,
                        orderPublicId,
                        request
                )
        );
    }

    private ApiResponse<OrderResponse> transition(
            Jwt jwt,
            Long storeId,
            String orderPublicId,
            OrderStatus targetStatus,
            String reason
    ) {
        return ApiResponse.success(
                orderCommandService.transitionBySeller(
                        currentUserService.getRequired(jwt),
                        storeId,
                        orderPublicId,
                        targetStatus,
                        reason
                )
        );
    }
}
