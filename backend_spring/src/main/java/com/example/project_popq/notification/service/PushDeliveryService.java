package com.example.project_popq.notification.service;

import com.example.project_popq.notification.domain.UserNotification;
import com.example.project_popq.notification.push.PushMessage;
import com.example.project_popq.notification.push.PushNotificationGateway;
import com.example.project_popq.notification.repository.PushDeviceRepository;
import com.example.project_popq.notification.repository.UserNotificationRepository;
import com.example.project_popq.user.repository.UserRepository;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class PushDeliveryService {

  private final PushDeviceRepository pushDeviceRepository;
  private final UserNotificationRepository userNotificationRepository;
  private final UserRepository userRepository;
  private final PushNotificationGateway pushNotificationGateway;

  public void deliver(UserNotification notification) {
    Long userId = notification.getUser().getId();

    long unreadCount =
        userNotificationRepository
            .countByUserIdAndReadFalse(userId);

    deliverToUser(
        userId,
        notification.getTitle(),
        notification.getMessage(),
        Map.of(
            "notificationId",
            notification.getId().toString(),
            "type",
            notification.getType().name(),
            "targetType",
            notification.getTargetType().name(),
            "targetId",
            notification.getTargetId(),
            "deepLink",
            notification.getDeepLink(),
            "badgeCount",
            Long.toString(unreadCount)
        )
    );
  }

  public void deliverToUser(
      Long userId,
      String title,
      String body,
      Map<String, String> data
  ) {
    boolean pushEnabled =
        userRepository
            .existsByIdAndPushNotificationEnabledTrue(
                userId
            );

    boolean hasBadgeCount =
        data.containsKey("badgeCount");

    if (!pushEnabled && !hasBadgeCount) {
      return;
    }

    pushDeviceRepository
        .findAllByUserIdOrderByCreatedAtDesc(userId)
        .forEach(device ->
            pushNotificationGateway.send(
                new PushMessage(
                    device.getToken(),
                    title,
                    body,
                    data,
                    pushEnabled
                )
            )
        );
  }
}