package com.example.project_popq.realtime.chat;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class OrderChatRealtimeEventListener {

  private final OrderChatMessagePublisher messagePublisher;

  @TransactionalEventListener(
      phase = TransactionPhase.AFTER_COMMIT
  )
  public void onOrderChatEvent(
      OrderChatEvent event
  ) {
    messagePublisher.publish(event);
  }
}