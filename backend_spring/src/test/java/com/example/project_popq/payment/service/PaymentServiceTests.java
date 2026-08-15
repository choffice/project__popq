package com.example.project_popq.payment.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.domain.OrderTransition;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.order.service.GuestOrderService;
import com.example.project_popq.payment.config.PaymentProperties;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.PaymentProviderType;
import com.example.project_popq.payment.domain.PaymentStatus;
import com.example.project_popq.payment.dto.ConfirmPaymentRequest;
import com.example.project_popq.payment.provider.PaymentApprovalCommand;
import com.example.project_popq.payment.provider.PaymentApprovalResult;
import com.example.project_popq.payment.provider.PaymentProvider;
import com.example.project_popq.payment.provider.PaymentProviderRegistry;
import com.example.project_popq.payment.repository.PaymentRepository;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import com.example.project_popq.realtime.event.OrderDomainEventPublisher;
import com.example.project_popq.point.service.CustomerPointService;
import com.example.project_popq.store.domain.Store;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class PaymentServiceTests {

    @Test
    void resumesAnUncertainInProgressApprovalWithTheSameKeys() {
        GuestQrService guestQrService = mock(GuestQrService.class);
        GuestOrderService guestOrderService = mock(GuestOrderService.class);
        OrderRepository orderRepository = mock(OrderRepository.class);
        PaymentRepository paymentRepository = mock(PaymentRepository.class);

        PaymentProvider paymentProvider = mock(PaymentProvider.class);
        PaymentProviderRegistry paymentProviderRegistry =
            mock(PaymentProviderRegistry.class);

        OrderDomainEventPublisher eventPublisher = mock(
            OrderDomainEventPublisher.class
        );
        CustomerPointService customerPointService = mock(
            CustomerPointService.class
        );

        Payment payment = mock(Payment.class);
        Order order = mock(Order.class);
        Store store = mock(Store.class);

        AtomicReference<PaymentStatus> status = new AtomicReference<>(
            PaymentStatus.IN_PROGRESS
        );

        when(guestQrService.resolve("guest-session"))
            .thenReturn(
                new ResolvedGuestSession(
                    7L,
                    1L,
                    null
                )
            );

        when(
            paymentRepository.findForUpdateByIdempotencyKey(
                "payment-key"
            )
        ).thenReturn(Optional.of(payment));

        when(payment.getStatus())
            .thenAnswer(ignored -> status.get());

        when(payment.getOrder())
            .thenReturn(order);

        when(payment.getProvider())
            .thenReturn(PaymentProviderType.TOSS_PAYMENTS);

        when(payment.getProviderPaymentKey())
            .thenReturn("toss-client-payment-key");

        when(order.getOrderPublicId())
            .thenReturn("order-123456");

        when(order.getTotalAmount())
            .thenReturn(6800L);

        when(order.getStatus())
            .thenReturn(OrderStatus.CREATED);

        when(order.getStore())
            .thenReturn(store);

        when(store.isOrderAccepting()).thenReturn(true);

        when(
            order.transitionTo(
                any(),
                any(),
                any(),
                any(),
                any()
            )
        ).thenReturn(mock(OrderTransition.class));

        when(
            paymentProviderRegistry.get(
                PaymentProviderType.TOSS_PAYMENTS
            )
        ).thenReturn(paymentProvider);

        when(
            paymentProvider.approve(any())
        ).thenReturn(
            PaymentApprovalResult.success(
                "toss-client-payment-key",
                6800
            )
        );

        org.mockito.Mockito.doAnswer(invocation -> {
            status.set(PaymentStatus.PAID);
            return null;
        }).when(payment).markPaid(
            any(Long.class),
            any(),
            any()
        );

        PaymentService service = new PaymentService(
            guestQrService,
            guestOrderService,
            orderRepository,
            paymentRepository,
            paymentProviderRegistry,
            eventPublisher,
            new PaymentProperties(
                PaymentProviderType.TOSS_PAYMENTS
            ),
            customerPointService
        );

        service.confirm(
            "guest-session",
            "order-123456",
            new ConfirmPaymentRequest(
                "payment-key",
                false,
                "toss-client-payment-key"
            )
        );

        ArgumentCaptor<PaymentApprovalCommand> command =
            ArgumentCaptor.forClass(
                PaymentApprovalCommand.class
            );

        verify(paymentProvider)
            .approve(command.capture());

        verify(customerPointService).rewardPayment(eq(payment), any());

        assertThat(
            command.getValue().idempotencyKey()
        ).isEqualTo("payment-key");

        assertThat(
            command.getValue().paymentKey()
        ).isEqualTo("toss-client-payment-key");

        verify(payment).markPaid(
            eq(6800L),
            eq("toss-client-payment-key"),
            any()
        );

        verify(guestOrderService)
            .requireGuestOwnership(
                order,
                7L
            );
    }
}
