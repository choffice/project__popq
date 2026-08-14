package com.example.project_popq.realtime.support;

import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class SupportTicketRealtimeMessagePublisher {

  private final SimpMessagingTemplate messagingTemplate;

  public void publish(SupportTicketRealtimeEvent event) {
    messagingTemplate.convertAndSend(
        "/topic/admin/support/tickets",
        event
    );

    messagingTemplate.convertAndSendToUser(
        String.valueOf(event.requesterUserId()),
        "/queue/support/tickets",
        event
    );
  }
}