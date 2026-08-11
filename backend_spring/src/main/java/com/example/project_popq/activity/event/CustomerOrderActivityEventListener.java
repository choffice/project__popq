package com.example.project_popq.activity.event;

import com.example.project_popq.activity.service.CustomerActivityService;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.realtime.event.OrderRealtimeEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class CustomerOrderActivityEventListener {

    private final CustomerActivityService customerActivityService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderChanged(OrderRealtimeEvent event) {
        if (event.userId() == null) {
            return;
        }

        if (event.currentStatus() == OrderStatus.PLACED) {
            customerActivityService.recordOrderPurchase(
                    event.userId(),
                    event.storeId(),
                    event.orderPublicId(),
                    event.occurredAt()
            );
            return;
        }

        if (event.currentStatus() == OrderStatus.CANCELED
                || event.currentStatus() == OrderStatus.REJECTED) {
            customerActivityService.revokeOrderPurchase(
                    event.orderPublicId(),
                    event.occurredAt()
            );
        }
    }
}
