package com.example.project_popq.realtime.support;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class SupportTicketRealtimeEventListener {

  private final SupportTicketRealtimeMessagePublisher messagePublisher;

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void onSupportTicketChanged(SupportTicketRealtimeEvent event) {
    messagePublisher.publish(event);
  }
}