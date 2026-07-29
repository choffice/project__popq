package com.example.project_popq.notification.service;

import com.example.project_popq.notification.domain.UserNotification;
import com.example.project_popq.notification.push.PushMessage;
import com.example.project_popq.notification.push.PushNotificationGateway;
import com.example.project_popq.notification.repository.PushDeviceRepository;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class PushDeliveryService {

    private final PushDeviceRepository pushDeviceRepository;
    private final PushNotificationGateway pushNotificationGateway;

    public void deliver(UserNotification notification) {
        pushDeviceRepository
                .findAllByUserIdOrderByCreatedAtDesc(
                        notification.getUser().getId()
                )
                .forEach(device -> pushNotificationGateway.send(
                        new PushMessage(
                                device.getToken(),
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
                                        notification.getDeepLink()
                                )
                        )
                ));
    }
}
