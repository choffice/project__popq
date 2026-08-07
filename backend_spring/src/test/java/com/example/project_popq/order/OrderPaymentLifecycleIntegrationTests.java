package com.example.project_popq.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.project_popq.analytics.service.SalesAnalyticsService;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderType;
import com.example.project_popq.order.dto.CreateGuestOrderRequest;
import com.example.project_popq.order.dto.CreateGuestOrderRequest.OrderItemRequest;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.order.service.GuestOrderService;
import com.example.project_popq.order.service.OrderCommandService;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.payment.domain.RefundStatus;
import com.example.project_popq.payment.dto.ConfirmPaymentRequest;
import com.example.project_popq.payment.dto.CreateSellerRefundRequest;
import com.example.project_popq.payment.dto.PaymentResponse;
import com.example.project_popq.payment.dto.SellerPaymentSummaryResponse;
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.payment.service.PaymentProcessingException;
import com.example.project_popq.payment.service.PaymentService;
import com.example.project_popq.payment.service.SellerRefundService;
import com.example.project_popq.product.dto.CreateCategoryRequest;
import com.example.project_popq.product.dto.CreateProductRequest;
import com.example.project_popq.product.dto.ProductDetailResponse;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest.OptionGroupRequest;
import com.example.project_popq.product.dto.ReplaceProductOptionsRequest.OptionRequest;
import com.example.project_popq.product.dto.UpdateAvailabilityRequest;
import com.example.project_popq.product.service.CatalogService;
import com.example.project_popq.qr.dto.IssueQrCodeRequest;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.SellerQrService;
import com.example.project_popq.realtime.event.OrderRealtimeEvent;
import com.example.project_popq.realtime.event.OrderRealtimeEventType;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
@RecordApplicationEvents
class OrderPaymentLifecycleIntegrationTests {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private StoreRepository storeRepository;

    @Autowired
    private StoreMemberRepository storeMemberRepository;

    @Autowired
    private CatalogService catalogService;

    @Autowired
    private SellerQrService sellerQrService;

    @Autowired
    private GuestQrService guestQrService;

    @Autowired
    private GuestOrderService guestOrderService;

    @Autowired
    private PaymentService paymentService;

    @Autowired
    private OrderCommandService orderCommandService;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private SellerRefundService sellerRefundService;

    @Autowired
    private SalesAnalyticsService salesAnalyticsService;

    @Autowired
    private ApplicationEvents applicationEvents;

    @Test
    void serverCalculatesSnapshotAmountAndProtectsOrderIdempotency() {
        Fixture fixture = createFixture();
        CreateGuestOrderRequest request = orderRequest(
                fixture,
                "order-key-0001",
                2
        );

        OrderResponse created = guestOrderService.create(
                fixture.guestSessionToken(),
                request
        );
        OrderResponse replay = guestOrderService.create(
                fixture.guestSessionToken(),
                request
        );

        assertThat(created.totalAmount()).isEqualTo(10_000);
        assertThat(created.items()).singleElement()
                .satisfies(item -> {
                    assertThat(item.productName()).isEqualTo("아메리카노");
                    assertThat(item.unitPrice()).isEqualTo(4_500);
                    assertThat(item.itemTotalPrice()).isEqualTo(10_000);
                });
        assertThat(replay.orderPublicId()).isEqualTo(created.orderPublicId());

        CreateGuestOrderRequest conflicting = orderRequest(
                fixture,
                "order-key-0001",
                3
        );
        assertErrorCode(
                () -> guestOrderService.create(
                        fixture.guestSessionToken(),
                        conflicting
                ),
                ErrorCode.IDEMPOTENCY_CONFLICT
        );
    }

    @Test
    void soldOutProductAndUnknownOptionAreRejectedAtOrderTime() {
        Fixture soldOutFixture = createFixture();
        catalogService.updateAvailability(
                soldOutFixture.seller(),
                soldOutFixture.store().getId(),
                soldOutFixture.productId(),
                new UpdateAvailabilityRequest(true, null, null, true, true)
        );
        assertErrorCode(
                () -> guestOrderService.create(
                        soldOutFixture.guestSessionToken(),
                        orderRequest(soldOutFixture, "order-soldout-1", 1)
                ),
                ErrorCode.PRODUCT_UNAVAILABLE
        );

        Fixture unknownOptionFixture = createFixture();
        CreateGuestOrderRequest unknownOption = new CreateGuestOrderRequest(
                "order-option-001",
                OrderType.TAKEOUT,
                List.of(new OrderItemRequest(
                        unknownOptionFixture.productId(),
                        1,
                        List.of(Long.MAX_VALUE)
                ))
        );
        assertErrorCode(
                () -> guestOrderService.create(
                        unknownOptionFixture.guestSessionToken(),
                        unknownOption
                ),
                ErrorCode.OPTION_NOT_FOUND
        );
    }

    @Test
    void paymentIsIdempotentAndPlacesOrderWithStatusHistory() {
        Fixture fixture = createFixture();
        OrderResponse order = createOrder(fixture, "order-pay-0001");
        ConfirmPaymentRequest request = new ConfirmPaymentRequest(
                "payment-key-001",
                false
        );

        PaymentResponse paid = paymentService.confirm(
                fixture.guestSessionToken(),
                order.orderPublicId(),
                request
        );
        PaymentResponse replay = paymentService.confirm(
                fixture.guestSessionToken(),
                order.orderPublicId(),
                request
        );
        OrderResponse placed = guestOrderService.get(
                fixture.guestSessionToken(),
                order.orderPublicId()
        );

        assertThat(paid.status()).isEqualTo(PaymentStatus.PAID);
        assertThat(paid.approvedAmount()).isEqualTo(order.totalAmount());
        assertThat(replay.paymentId()).isEqualTo(paid.paymentId());
        assertThat(placed.status()).isEqualTo(OrderStatus.PLACED);
        assertThat(placed.version()).isEqualTo(1);
        assertThat(placed.statusHistory())
                .extracting(OrderResponse.OrderStatusHistoryResponse::currentStatus)
                .containsExactly(OrderStatus.CREATED, OrderStatus.PLACED);
        assertThat(applicationEvents.stream(OrderRealtimeEvent.class).toList())
                .singleElement()
                .satisfies(event -> {
                    assertThat(event.eventType())
                            .isEqualTo(OrderRealtimeEventType.ORDER_PLACED);
                    assertThat(event.version()).isEqualTo(1);
                    assertThat(event.orderPublicId())
                            .isEqualTo(order.orderPublicId());
                });
    }

    @Test
    void failedPaymentIsRecordedWithoutPlacingOrder() {
        Fixture fixture = createFixture();
        OrderResponse order = createOrder(fixture, "order-fail-001");

        assertThatThrownBy(() -> paymentService.confirm(
                fixture.guestSessionToken(),
                order.orderPublicId(),
                new ConfirmPaymentRequest("payment-fail-01", true)
        ))
                .isInstanceOfSatisfying(
                        PaymentProcessingException.class,
                        exception -> assertThat(exception.getErrorCode())
                                .isEqualTo(ErrorCode.PAYMENT_FAILED)
                );

        Order persistedOrder = orderRepository
                .findByOrderPublicId(order.orderPublicId())
                .orElseThrow();
        Payment failed = paymentRepository
                .findByOrderId(persistedOrder.getId())
                .orElseThrow();
        assertThat(persistedOrder.getStatus()).isEqualTo(OrderStatus.CREATED);
        assertThat(failed.getStatus()).isEqualTo(PaymentStatus.FAILED);
        assertThat(applicationEvents.stream(OrderRealtimeEvent.class))
                .isEmpty();
        assertThat(failed.getTransactions()).singleElement()
                .satisfies(transaction -> assertThat(
                        transaction.getFailureCode()
                ).isEqualTo("TEST_PAYMENT_FAILED"));
    }

    @Test
    void guestCancellationRefundsPaidOrder() {
        Fixture fixture = createFixture();
        OrderResponse order = createAndPay(
                fixture,
                "order-cancel-01",
                "payment-cancel-01"
        );

        OrderResponse canceled = orderCommandService.cancelByGuest(
                fixture.guestSessionToken(),
                order.orderPublicId(),
                "고객 변심"
        );
        Order persistedOrder = orderRepository
                .findByOrderPublicId(order.orderPublicId())
                .orElseThrow();
        Payment payment = paymentRepository
                .findByOrderId(persistedOrder.getId())
                .orElseThrow();

        assertThat(canceled.status()).isEqualTo(OrderStatus.CANCELED);
        assertThat(payment.getStatus()).isEqualTo(PaymentStatus.CANCELED);
        assertThat(payment.getRefunds()).singleElement()
                .satisfies(refund -> {
                    assertThat(refund.getStatus()).isEqualTo(RefundStatus.SUCCEEDED);
                    assertThat(refund.getAmount()).isEqualTo(order.totalAmount());
                });
    }

    @Test
    void sellerTransitionsAreValidatedAndRejectRefundsOrder() {
        Fixture flowFixture = createFixture();
        OrderResponse flowOrder = createAndPay(
                flowFixture,
                "order-flow-0001",
                "payment-flow-01"
        );
        OrderResponse accepted = transition(
                flowFixture,
                flowOrder,
                OrderStatus.ACCEPTED
        );
        assertThat(accepted.status()).isEqualTo(OrderStatus.ACCEPTED);
        assertErrorCode(
                () -> orderCommandService.cancelByGuest(
                        flowFixture.guestSessionToken(),
                        flowOrder.orderPublicId(),
                        "너무 늦음"
                ),
                ErrorCode.ORDER_CANNOT_CANCEL
        );
        assertErrorCode(
                () -> transition(flowFixture, flowOrder, OrderStatus.READY),
                ErrorCode.INVALID_ORDER_STATUS
        );
        assertThat(transition(
                flowFixture,
                flowOrder,
                OrderStatus.PREPARING
        ).status()).isEqualTo(OrderStatus.PREPARING);
        assertThat(transition(
                flowFixture,
                flowOrder,
                OrderStatus.READY
        ).status()).isEqualTo(OrderStatus.READY);
        assertThat(transition(
                flowFixture,
                flowOrder,
                OrderStatus.COMPLETED
        ).status()).isEqualTo(OrderStatus.COMPLETED);

        Fixture rejectFixture = createFixture();
        OrderResponse rejectOrder = createAndPay(
                rejectFixture,
                "order-reject-01",
                "payment-reject-1"
        );
        OrderResponse rejected = transition(
                rejectFixture,
                rejectOrder,
                OrderStatus.REJECTED
        );
        Order persistedOrder = orderRepository
                .findByOrderPublicId(rejectOrder.orderPublicId())
                .orElseThrow();
        Payment payment = paymentRepository
                .findByOrderId(persistedOrder.getId())
                .orElseThrow();

        assertThat(rejected.status()).isEqualTo(OrderStatus.REJECTED);
        assertThat(payment.getStatus()).isEqualTo(PaymentStatus.CANCELED);
        assertThat(payment.getRefunds()).singleElement()
                .satisfies(refund -> assertThat(refund.getStatus())
                        .isEqualTo(RefundStatus.SUCCEEDED));
    }

    @Test
    void anotherGuestAndAnotherStoreCannotAccessOrder() {
        Fixture owner = createFixture();
        Fixture stranger = createFixture();
        OrderResponse order = createOrder(owner, "order-access-01");

        assertErrorCode(
                () -> guestOrderService.get(
                        stranger.guestSessionToken(),
                        order.orderPublicId()
                ),
                ErrorCode.ORDER_ACCESS_DENIED
        );
        assertErrorCode(
                () -> orderCommandService.findSellerOrder(
                        stranger.seller(),
                        owner.store().getId(),
                        order.orderPublicId()
                ),
                ErrorCode.STORE_ACCESS_DENIED
        );
    }

    @Test
    void ownerCanFullyRefundCompletedOrderAndSummaryTracksIt() {
        Fixture fixture = createFixture();
        OrderResponse order = createAndPay(
                fixture,
                "order-seller-refund-01",
                "payment-seller-refund-01"
        );
        order = transition(fixture, order, OrderStatus.ACCEPTED);
        order = transition(fixture, order, OrderStatus.PREPARING);
        order = transition(fixture, order, OrderStatus.READY);
        OrderResponse completed = transition(
                fixture,
                order,
                OrderStatus.COMPLETED
        );

        SellerPaymentSummaryResponse before = sellerRefundService.findSummary(
                fixture.seller(),
                fixture.store().getId(),
                completed.orderPublicId()
        );
        assertThat(before.paymentStatus()).isEqualTo(PaymentStatus.PAID);
        assertThat(before.refundableAmount()).isEqualTo(completed.totalAmount());
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Seoul"));
        assertThat(salesAnalyticsService.summarize(
                fixture.seller(),
                fixture.store().getId(),
                today,
                today
        ).netSales()).isEqualTo(completed.totalAmount());

        SellerPaymentSummaryResponse refunded =
                sellerRefundService.refundCompletedOrder(
                        fixture.seller(),
                        fixture.store().getId(),
                        completed.orderPublicId(),
                        new CreateSellerRefundRequest(
                                completed.totalAmount(),
                                "고객 요청 전액 환불"
                        )
                );

        assertThat(refunded.paymentStatus()).isEqualTo(PaymentStatus.REFUNDED);
        assertThat(refunded.refundedAmount()).isEqualTo(completed.totalAmount());
        assertThat(refunded.refundableAmount()).isZero();
        assertThat(refunded.refunds()).singleElement()
                .satisfies(refund -> {
                    assertThat(refund.status()).isEqualTo(RefundStatus.SUCCEEDED);
                    assertThat(refund.reason()).isEqualTo("고객 요청 전액 환불");
                });
        var afterRefund = salesAnalyticsService.summarize(
                fixture.seller(),
                fixture.store().getId(),
                today,
                today
        );
        assertThat(afterRefund.grossSales()).isEqualTo(completed.totalAmount());
        assertThat(afterRefund.refundedAmount()).isEqualTo(completed.totalAmount());
        assertThat(afterRefund.refundCount()).isEqualTo(1);
        assertThat(afterRefund.netSales()).isZero();
        assertErrorCode(
                () -> sellerRefundService.refundCompletedOrder(
                        fixture.seller(),
                        fixture.store().getId(),
                        completed.orderPublicId(),
                        new CreateSellerRefundRequest(
                                completed.totalAmount(),
                                "중복 환불"
                        )
                ),
                ErrorCode.REFUND_NOT_ALLOWED
        );
    }

    @Test
    void ownerCanRefundCompletedOrderInMultiplePartialAmounts() {
        Fixture fixture = createFixture();
        OrderResponse order = createAndPay(
                fixture,
                "order-partial-refund-01",
                "payment-partial-refund-01"
        );
        order = transition(fixture, order, OrderStatus.ACCEPTED);
        order = transition(fixture, order, OrderStatus.PREPARING);
        order = transition(fixture, order, OrderStatus.READY);
        OrderResponse completed = transition(
                fixture,
                order,
                OrderStatus.COMPLETED
        );
        long firstAmount = completed.totalAmount() / 2;

        SellerPaymentSummaryResponse partial =
                sellerRefundService.refundCompletedOrder(
                        fixture.seller(),
                        fixture.store().getId(),
                        completed.orderPublicId(),
                        new CreateSellerRefundRequest(
                                firstAmount,
                                "1차 부분 환불"
                        )
                );

        assertThat(partial.paymentStatus())
                .isEqualTo(PaymentStatus.PARTIALLY_REFUNDED);
        assertThat(partial.refundedAmount()).isEqualTo(firstAmount);
        assertThat(partial.refundableAmount())
                .isEqualTo(completed.totalAmount() - firstAmount);

        SellerPaymentSummaryResponse finished =
                sellerRefundService.refundCompletedOrder(
                        fixture.seller(),
                        fixture.store().getId(),
                        completed.orderPublicId(),
                        new CreateSellerRefundRequest(
                                partial.refundableAmount(),
                                "잔액 환불"
                        )
                );

        assertThat(finished.paymentStatus()).isEqualTo(PaymentStatus.REFUNDED);
        assertThat(finished.refundedAmount()).isEqualTo(completed.totalAmount());
        assertThat(finished.refundableAmount()).isZero();
        assertThat(finished.refunds()).hasSize(2);
    }

    @Test
    void staffCannotExecuteCompletedOrderRefund() {
        Fixture fixture = createFixture();
        OrderResponse order = createAndPay(
                fixture,
                "order-staff-refund-01",
                "payment-staff-refund-01"
        );
        order = transition(fixture, order, OrderStatus.ACCEPTED);
        order = transition(fixture, order, OrderStatus.PREPARING);
        order = transition(fixture, order, OrderStatus.READY);
        OrderResponse completed = transition(
                fixture,
                order,
                OrderStatus.COMPLETED
        );
        User staff = userRepository.save(
                User.create(
                        "refund-staff-" + UUID.randomUUID() + "@popq.test",
                        "환불 조회 담당자",
                        PlatformRole.SELLER
                )
        );
        storeMemberRepository.save(
                StoreMember.create(fixture.store(), staff, StoreRole.STAFF)
        );

        assertThat(sellerRefundService.findSummary(
                staff,
                fixture.store().getId(),
                completed.orderPublicId()
        ).paymentStatus()).isEqualTo(PaymentStatus.PAID);
        assertErrorCode(
                () -> sellerRefundService.refundCompletedOrder(
                        staff,
                        fixture.store().getId(),
                        completed.orderPublicId(),
                        new CreateSellerRefundRequest(
                                completed.totalAmount(),
                                "권한 없는 환불"
                        )
                ),
                ErrorCode.STORE_ACCESS_DENIED
        );
    }

    private OrderResponse transition(
            Fixture fixture,
            OrderResponse order,
            OrderStatus targetStatus
    ) {
        return orderCommandService.transitionBySeller(
                fixture.seller(),
                fixture.store().getId(),
                order.orderPublicId(),
                targetStatus,
                "통합 테스트 상태 변경"
        );
    }

    private OrderResponse createAndPay(
            Fixture fixture,
            String orderKey,
            String paymentKey
    ) {
        OrderResponse order = createOrder(fixture, orderKey);
        paymentService.confirm(
                fixture.guestSessionToken(),
                order.orderPublicId(),
                new ConfirmPaymentRequest(paymentKey, false)
        );
        return order;
    }

    private OrderResponse createOrder(Fixture fixture, String orderKey) {
        return guestOrderService.create(
                fixture.guestSessionToken(),
                orderRequest(fixture, orderKey, 1)
        );
    }

    private CreateGuestOrderRequest orderRequest(
            Fixture fixture,
            String idempotencyKey,
            int quantity
    ) {
        return new CreateGuestOrderRequest(
                idempotencyKey,
                OrderType.TAKEOUT,
                List.of(new OrderItemRequest(
                        fixture.productId(),
                        quantity,
                        List.of(fixture.optionId())
                ))
        );
    }

    private Fixture createFixture() {
        String suffix = UUID.randomUUID().toString();
        User seller = userRepository.save(
                User.create(
                        "order-" + suffix + "@popq.test",
                        "주문 테스트 판매자",
                        PlatformRole.SELLER
                )
        );
        Store store = storeRepository.save(
                Store.create(StoreType.LOCAL_STORE, "주문 테스트 매장", null)
        );
        store.changeBusinessStatus(BusinessStatus.OPEN);
        storeMemberRepository.save(
                StoreMember.create(store, seller, StoreRole.OWNER)
        );

        Long categoryId = catalogService.createCategory(
                seller,
                store.getId(),
                new CreateCategoryRequest("커피", 0)
        ).categoryId();
        ProductDetailResponse product = catalogService.createProduct(
                seller,
                store.getId(),
                new CreateProductRequest(
                        categoryId,
                        "아메리카노",
                        "주문 테스트 상품",
                        null,
                        4_500
                )
        );
        ProductDetailResponse configured = catalogService.replaceOptions(
                seller,
                store.getId(),
                product.product().productId(),
                new ReplaceProductOptionsRequest(List.of(
                        new OptionGroupRequest(
                                "온도",
                                1,
                                1,
                                true,
                                0,
                                List.of(
                                        new OptionRequest("ICE", 500, 0),
                                        new OptionRequest("HOT", 0, 1)
                                )
                        )
                ))
        );
        String qrToken = sellerQrService.issue(
                seller,
                store.getId(),
                new IssueQrCodeRequest(null, null)
        ).token();
        String guestSessionToken = guestQrService.open(qrToken).rawToken();
        Long optionId = configured.optionGroups().get(0).options().get(0).optionId();
        return new Fixture(
                seller,
                store,
                product.product().productId(),
                optionId,
                guestSessionToken
        );
    }

    private void assertErrorCode(Runnable operation, ErrorCode expected) {
        assertThatThrownBy(operation::run)
                .isInstanceOfSatisfying(
                        BusinessException.class,
                        exception -> assertThat(exception.getErrorCode())
                                .isEqualTo(expected)
                );
    }

    private record Fixture(
            User seller,
            Store store,
            Long productId,
            Long optionId,
            String guestSessionToken
    ) {
    }
}
