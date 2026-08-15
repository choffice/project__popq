package com.example.project_popq.realtime.support;

import com.example.project_popq.support.domain.SupportSenderType;
import com.example.project_popq.support.domain.SupportTicket;
import java.time.Instant;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class SupportTicketDomainEventPublisher {

  private final ApplicationEventPublisher applicationEventPublisher;

  public void publish(
      SupportTicket ticket,
      SupportTicketRealtimeEventType eventType,
      SupportSenderType senderType,
      Instant occurredAt
  ) {
    applicationEventPublisher.publishEvent(
        new SupportTicketRealtimeEvent(
            UUID.randomUUID().toString(),
            eventType,
            ticket.getId(),
            ticket.getRequester().getId(),
            ticket.getRequesterType(),
            senderType,
            ticket.getStatus(),
            occurredAt
        )
    );
  }
}