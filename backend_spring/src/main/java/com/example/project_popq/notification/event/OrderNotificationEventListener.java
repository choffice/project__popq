package com.example.project_popq.notification.event;

import com.example.project_popq.notification.service.CustomerNotificationService;
import com.example.project_popq.realtime.event.OrderRealtimeEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class OrderNotificationEventListener {

    private final CustomerNotificationService notificationService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderChanged(OrderRealtimeEvent event) {
        notificationService.recordOrderEvent(event);
    }
}
