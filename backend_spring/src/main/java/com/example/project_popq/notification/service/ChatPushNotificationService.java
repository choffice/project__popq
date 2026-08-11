package com.example.project_popq.notification.service;

import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.realtime.chat.OrderChatEvent;
import com.example.project_popq.realtime.chat.OrderChatEventType;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMemberStatus;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import java.util.Locale;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ChatPushNotificationService {

  private static final int MESSAGE_PREVIEW_LENGTH = 120;

  private final StoreMemberRepository storeMemberRepository;
  private final StoreRepository storeRepository;
  private final PushDeliveryService pushDeliveryService;
  private final CustomerBadgeCountService customerBadgeCountService;

  @Transactional(readOnly = true)
  public void sendFor(OrderChatEvent event) {
    if (event.eventType() != OrderChatEventType.MESSAGE_CREATED
        || event.message() == null) {
      return;
    }

    if (event.message().senderType() == MessageSenderType.CUSTOMER) {
      sendToSellers(event);
      return;
    }

    if (event.message().senderType() == MessageSenderType.SELLER) {
      sendToCustomer(event);
    }
  }

  private void sendToSellers(OrderChatEvent event) {
    String orderPublicId = event.orderPublicId();
    String title = customerTitle(
        event.message().senderName(),
        orderPublicId
    );
    String body = messagePreview(event.message().content());

    Map<String, String> data = Map.of(
        "type", "CHAT_MESSAGE",
        "targetType", "ORDER_CHAT",
        "targetId", orderPublicId,
        "orderPublicId", orderPublicId,
        "senderType", MessageSenderType.CUSTOMER.name(),
        "deepLink", "/customers/" + orderPublicId
            + "?storeId=" + event.storeId()
    );

    storeMemberRepository
        .findAllByStoreIdAndStatusOrderByIdAsc(
            event.storeId(),
            StoreMemberStatus.ACTIVE
        )
        .forEach(storeMember ->
            pushDeliveryService.deliverToUser(
                storeMember.getUser().getId(),
                title,
                body,
                data
            )
        );
  }

  private void sendToCustomer(OrderChatEvent event) {
    if (event.customerUserId() == null) {
      return;
    }

    String orderPublicId = event.orderPublicId();

    String title = storeRepository
        .findById(event.storeId())
        .map(Store::getName)
        .filter(name -> !name.isBlank())
        .orElse("POPQ 문의");

    String body = messagePreview(event.message().content());

    long badgeCount =
        customerBadgeCountService
            .countUnread(event.customerUserId());

    Map<String, String> data = Map.of(
        "type", "CHAT_MESSAGE",
        "targetType", "ORDER_CHAT",
        "targetId", orderPublicId,
        "orderPublicId", orderPublicId,
        "senderType", MessageSenderType.SELLER.name(),
        "deepLink", "/orders/" + orderPublicId + "/messages",
        "badgeCount", Long.toString(badgeCount)
    );

    pushDeliveryService.deliverToUser(
        event.customerUserId(),
        title,
        body,
        data
    );
  }

  private String customerTitle(
      String customerName,
      String orderPublicId
  ) {
    String normalizedName =
        customerName == null || customerName.isBlank()
            ? "POPQ 고객"
            : customerName.trim();

    if (!normalizedName.endsWith("님")) {
      normalizedName += "님";
    }

    return normalizedName + " · #" + shortOrderNumber(orderPublicId);
  }

  private String shortOrderNumber(String orderPublicId) {
    String normalized = orderPublicId
        .replace("-", "")
        .toUpperCase(Locale.ROOT);

    return normalized.substring(
        0,
        Math.min(8, normalized.length())
    );
  }

  private String messagePreview(String content) {
    String normalized = content
        .replaceAll("\\s+", " ")
        .trim();

    if (normalized.length() <= MESSAGE_PREVIEW_LENGTH) {
      return normalized;
    }

    return normalized.substring(
        0,
        MESSAGE_PREVIEW_LENGTH
    ) + "…";
  }
}