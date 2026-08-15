package com.example.project_popq.point.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.project_popq.order.domain.Order;
import com.example.project_popq.payment.domain.Payment;
import com.example.project_popq.payment.domain.Refund;
import com.example.project_popq.payment.domain.RefundStatus;
import com.example.project_popq.point.domain.CustomerPointTransaction;
import com.example.project_popq.point.repository.CustomerPointTransactionRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class CustomerPointServiceTests {

    @Test
    void rewardsTwoPointFivePercentOfApprovedPaymentAmount() {
        CustomerPointTransactionRepository repository = mock(
                CustomerPointTransactionRepository.class
        );
        CustomerPointService service = new CustomerPointService(repository);
        Payment payment = mockPayment(12345L);
        Instant occurredAt = Instant.parse("2026-08-12T01:00:00Z");

        when(repository.existsBySourceKey("PAYMENT:11")).thenReturn(false);

        service.rewardPayment(payment, occurredAt);

        ArgumentCaptor<CustomerPointTransaction> captor =
                ArgumentCaptor.forClass(CustomerPointTransaction.class);
        verify(repository).save(captor.capture());
        CustomerPointTransaction saved = captor.getValue();

        assertThat(saved.getPointAmount()).isEqualTo(308L);
        assertThat(saved.getPaymentAmount()).isEqualTo(12345L);
        assertThat(saved.getSourceKey()).isEqualTo("PAYMENT:11");
        assertThat(saved.getOccurredAt()).isEqualTo(occurredAt);
    }

    @Test
    void reclaimsOnlyPointsRemovedByPartialRefund() {
        CustomerPointTransactionRepository repository = mock(
                CustomerPointTransactionRepository.class
        );
        CustomerPointService service = new CustomerPointService(repository);
        Payment payment = mockPayment(10000L);
        Refund refund = mock(Refund.class);
        Instant requestedAt = Instant.parse("2026-08-12T02:00:00Z");
        Instant completedAt = Instant.parse("2026-08-12T02:01:00Z");

        when(refund.getRequestedAt()).thenReturn(requestedAt);
        when(refund.getStatus()).thenReturn(RefundStatus.SUCCEEDED);
        when(refund.getAmount()).thenReturn(3333L);
        when(payment.getRefunds()).thenReturn(List.of(refund));
        when(repository.existsBySourceKey("REFUND:11:" + requestedAt))
                .thenReturn(false);
        when(repository.findBySourceKey("PAYMENT:11"))
                .thenReturn(Optional.of(mock(CustomerPointTransaction.class)));
        when(repository.findBalanceByUserIdAndOrderPublicId(6L, "ORDER-1"))
                .thenReturn(250L);

        service.reclaimRefund(payment, refund, completedAt);

        ArgumentCaptor<CustomerPointTransaction> captor =
                ArgumentCaptor.forClass(CustomerPointTransaction.class);
        verify(repository).save(captor.capture());
        CustomerPointTransaction saved = captor.getValue();

        assertThat(saved.getPointAmount()).isEqualTo(-84L);
        assertThat(saved.getPaymentAmount()).isEqualTo(3333L);
        assertThat(saved.getOccurredAt()).isEqualTo(completedAt);
    }

    @Test
    void spendsOneThousandPointsForRaffleTicket() {
        CustomerPointTransactionRepository repository = mock(
                CustomerPointTransactionRepository.class
        );
        CustomerPointService service = new CustomerPointService(repository);
        User user = mock(User.class);
        Instant occurredAt = Instant.parse("2026-08-12T03:00:00Z");

        service.spendRaffleTicket(
                user,
                31L,
                "2026-09",
                1000L,
                occurredAt
        );

        ArgumentCaptor<CustomerPointTransaction> captor =
                ArgumentCaptor.forClass(CustomerPointTransaction.class);
        verify(repository).save(captor.capture());
        CustomerPointTransaction saved = captor.getValue();

        assertThat(saved.getPointAmount()).isEqualTo(-1000L);
        assertThat(saved.getSourceKey()).isEqualTo("RAFFLE_TICKET:31");
        assertThat(saved.getOccurredAt()).isEqualTo(occurredAt);
    }

    private Payment mockPayment(long approvedAmount) {
        Payment payment = mock(Payment.class);
        Order order = mock(Order.class);
        User user = mock(User.class);
        Store store = mock(Store.class);

        when(payment.getId()).thenReturn(11L);
        when(payment.getOrder()).thenReturn(order);
        when(payment.getApprovedAmount()).thenReturn(approvedAmount);
        when(order.getUser()).thenReturn(user);
        when(order.getOrderPublicId()).thenReturn("ORDER-1");
        when(order.getStore()).thenReturn(store);
        when(user.getId()).thenReturn(6L);
        when(store.getName()).thenReturn("테스트 매장");

        return payment;
    }
}
