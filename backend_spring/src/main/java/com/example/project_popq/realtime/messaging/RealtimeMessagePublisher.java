package com.example.project_popq.realtime.messaging;

import com.example.project_popq.realtime.event.OrderRealtimeEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class RealtimeMessagePublisher {

    private final SimpMessagingTemplate messagingTemplate;

    public void publish(OrderRealtimeEvent event) {
        messagingTemplate.convertAndSend(
                "/topic/stores/" + event.storeId() + "/orders",
                event
        );

        if (event.userId() != null) {
            messagingTemplate.convertAndSendToUser(
                    String.valueOf(event.userId()),
                    "/queue/orders",
                    event
            );
            return;
        }

        if (event.guestSessionId() != null) {
            messagingTemplate.convertAndSendToUser(
                    GuestRealtimePrincipal.nameOf(event.guestSessionId()),
                    "/queue/orders/" + event.orderPublicId(),
                    event
            );
        }
    }
}
