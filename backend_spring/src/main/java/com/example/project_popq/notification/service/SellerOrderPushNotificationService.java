package com.example.project_popq.notification.service;

import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.realtime.event.OrderRealtimeEvent;
import com.example.project_popq.store.domain.StoreMemberStatus;
import com.example.project_popq.store.repository.StoreMemberRepository;
import java.util.Locale;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SellerOrderPushNotificationService {

    public static final String NEW_ORDER_NOTIFICATION_TYPE = "ORDER_PLACED";
    public static final String NEW_ORDER_ANDROID_CHANNEL_ID =
            "popq_new_orders_v1";
    public static final String NEW_ORDER_ANDROID_SOUND = "popq_order_arrived";

    private final StoreMemberRepository storeMemberRepository;
    private final PushDeliveryService pushDeliveryService;

    @Transactional(readOnly = true)
    public void sendFor(OrderRealtimeEvent event) {
        if (event.currentStatus() != OrderStatus.PLACED) {
            return;
        }

        String orderPublicId = event.orderPublicId();
        Map<String, String> data = Map.of(
                "type", NEW_ORDER_NOTIFICATION_TYPE,
                "targetType", "ORDER",
                "targetId", orderPublicId,
                "orderPublicId", orderPublicId,
                "storeId", event.storeId().toString(),
                "androidChannelId", NEW_ORDER_ANDROID_CHANNEL_ID,
                "androidSound", NEW_ORDER_ANDROID_SOUND,
                "deepLink", "/orders/" + orderPublicId
                        + "?storeId=" + event.storeId()
        );

        storeMemberRepository
                .findAllByStoreIdAndStatusOrderByIdAsc(
                        event.storeId(),
                        StoreMemberStatus.ACTIVE
                )
                .forEach(storeMember -> pushDeliveryService.deliverToUser(
                        storeMember.getUser().getId(),
                        "새 주문이 도착했어요",
                        "주문 #" + shortOrderNumber(orderPublicId)
                                + "을 확인해 주세요.",
                        data
                ));
    }

    private String shortOrderNumber(String orderPublicId) {
        String normalized = orderPublicId
                .replace("-", "")
                .toUpperCase(Locale.ROOT);
        return normalized.substring(0, Math.min(8, normalized.length()));
    }
}
