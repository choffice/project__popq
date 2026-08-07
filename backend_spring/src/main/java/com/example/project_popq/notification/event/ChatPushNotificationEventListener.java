package com.example.project_popq.notification.event;

import com.example.project_popq.notification.service.ChatPushNotificationService;
import com.example.project_popq.realtime.chat.OrderChatEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Slf4j
@Component
@RequiredArgsConstructor
public class ChatPushNotificationEventListener {

  private final ChatPushNotificationService chatPushNotificationService;

  @TransactionalEventListener(
      phase = TransactionPhase.AFTER_COMMIT
  )
  public void onOrderChatEvent(OrderChatEvent event) {
    try {
      chatPushNotificationService.sendFor(event);
    } catch (RuntimeException exception) {
      log.warn(
          "Chat push notification failed. eventId={}, orderPublicId={}, message={}",
          event.eventId(),
          event.orderPublicId(),
          exception.getMessage()
      );
    }
  }
}