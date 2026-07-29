package com.example.project_popq.realtime.event;

import com.example.project_popq.realtime.messaging.RealtimeMessagePublisher;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class OrderRealtimeEventListener {

    private final RealtimeMessagePublisher messagePublisher;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderChanged(OrderRealtimeEvent event) {
        messagePublisher.publish(event);
    }
}
