package com.example.project_popq.notification.event;

import com.example.project_popq.notification.service.SellerOrderPushNotificationService;
import com.example.project_popq.realtime.event.OrderRealtimeEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class SellerOrderPushNotificationEventListener {

    private final SellerOrderPushNotificationService notificationService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderPlaced(OrderRealtimeEvent event) {
        notificationService.sendFor(event);
    }
}
