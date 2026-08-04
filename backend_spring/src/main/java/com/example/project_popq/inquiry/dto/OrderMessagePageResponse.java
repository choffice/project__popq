package com.example.project_popq.inquiry.dto;

import com.example.project_popq.inquiry.domain.OrderMessage;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public record OrderMessagePageResponse(
    List<OrderMessageResponse> messages,
    boolean hasMore,
    Long nextBeforeMessageId
) {

  public static OrderMessagePageResponse of(
      List<OrderMessage> messagesInDescendingOrder,
      int requestedSize
  ) {
    boolean hasMore =
        messagesInDescendingOrder.size() > requestedSize;

    int resultSize = Math.min(
        messagesInDescendingOrder.size(),
        requestedSize
    );

    List<OrderMessage> pageMessages = new ArrayList<>(
        messagesInDescendingOrder.subList(0, resultSize)
    );

    Long nextBeforeMessageId =
        hasMore && !pageMessages.isEmpty()
            ? pageMessages.get(pageMessages.size() - 1).getId()
            : null;

    Collections.reverse(pageMessages);

    return new OrderMessagePageResponse(
        pageMessages.stream()
            .map(OrderMessageResponse::from)
            .toList(),
        hasMore,
        nextBeforeMessageId
    );
  }
}
