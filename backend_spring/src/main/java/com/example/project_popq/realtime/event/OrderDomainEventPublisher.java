package com.example.project_popq.realtime.event;

import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.domain.OrderTransition;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class OrderDomainEventPublisher {

    private final ApplicationEventPublisher applicationEventPublisher;

    public void publish(Order order, OrderTransition transition) {
        Long guestSessionId = order.getGuestSession() == null
                ? null
                : order.getGuestSession().getId();
        Long userId = order.getUser() == null
                ? null
                : order.getUser().getId();
        applicationEventPublisher.publishEvent(new OrderRealtimeEvent(
                UUID.randomUUID().toString(),
                OrderRealtimeEventType.from(transition.currentStatus()),
                order.getOrderPublicId(),
                order.getStore().getId(),
                guestSessionId,
                userId,
                transition.previousStatus(),
                transition.currentStatus(),
                transition.occurredAt(),
                order.getVersion()
        ));
    }
}
