package com.example.project_popq.realtime.chat;

import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.domain.OrderMessage;
import com.example.project_popq.order.domain.Order;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class OrderChatDomainEventPublisher {

  private final ApplicationEventPublisher applicationEventPublisher;

  public void publishMessageCreated(
      OrderMessage message
  ) {
    applicationEventPublisher.publishEvent(
        OrderChatEvent.messageCreated(message)
    );
  }

  public void publishMessagesRead(
      Order order,
      MessageSenderType readerType,
      List<Long> readMessageIds,
      Instant readAt
  ) {
    if (readMessageIds == null || readMessageIds.isEmpty()) {
      return;
    }

    applicationEventPublisher.publishEvent(
        OrderChatEvent.messagesRead(
            order,
            readerType,
            readMessageIds,
            readAt
        )
    );
  }
}