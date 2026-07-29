package com.example.project_popq.realtime;

import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.realtime.event.OrderRealtimeEvent;
import com.example.project_popq.realtime.event.OrderRealtimeEventType;
import com.example.project_popq.realtime.messaging.RealtimeMessagePublisher;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest
@ActiveProfiles("test")
class OrderRealtimeCommitIntegrationTests {

    @Autowired
    private ApplicationEventPublisher applicationEventPublisher;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @MockitoBean
    private RealtimeMessagePublisher messagePublisher;

    @Test
    void eventIsDeliveredOnlyAfterCommit() {
        OrderRealtimeEvent event = event("commit-event");
        TransactionTemplate transaction = new TransactionTemplate(
                transactionManager
        );

        transaction.executeWithoutResult(status -> {
            applicationEventPublisher.publishEvent(event);
            verifyNoInteractions(messagePublisher);
        });

        verify(messagePublisher).publish(event);
    }

    @Test
    void rolledBackEventIsNeverDelivered() {
        OrderRealtimeEvent event = event("rollback-event");
        TransactionTemplate transaction = new TransactionTemplate(
                transactionManager
        );

        transaction.executeWithoutResult(status -> {
            applicationEventPublisher.publishEvent(event);
            status.setRollbackOnly();
        });

        verify(messagePublisher, never()).publish(event);
        clearInvocations(messagePublisher);
    }

    private OrderRealtimeEvent event(String eventId) {
        return new OrderRealtimeEvent(
                eventId,
                OrderRealtimeEventType.ORDER_PLACED,
                "order-public-id",
                1L,
                2L,
                OrderStatus.CREATED,
                OrderStatus.PLACED,
                Instant.parse("2026-07-29T00:00:00Z"),
                1L
        );
    }
}
