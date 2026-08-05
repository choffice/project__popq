package com.example.project_popq.realtime.chat;

import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class OrderChatMessagePublisher {

  private final SimpMessagingTemplate messagingTemplate;

  public void publish(OrderChatEvent event) {
    publishToOrderChannel(event);
    publishToStoreChannel(event);
    publishToCustomerChannel(event);
  }

  private void publishToOrderChannel(
      OrderChatEvent event
  ) {
    messagingTemplate.convertAndSend(
        "/topic/orders/"
            + event.orderPublicId()
            + "/chat",
        event
    );
  }

  private void publishToStoreChannel(
      OrderChatEvent event
  ) {
    messagingTemplate.convertAndSend(
        "/topic/stores/"
            + event.storeId()
            + "/chat",
        event
    );
  }

  private void publishToCustomerChannel(
      OrderChatEvent event
  ) {
    if (event.customerUserId() == null) {
      return;
    }

    messagingTemplate.convertAndSendToUser(
        String.valueOf(event.customerUserId()),
        "/queue/chat",
        event
    );
  }
}