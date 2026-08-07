package com.example.project_popq.notification.service;

import com.example.project_popq.announcement.domain.Announcement;
import com.example.project_popq.engagement.repository.StoreInterestRepository;
import com.example.project_popq.notification.domain.UserNotification;
import com.example.project_popq.notification.repository.UserNotificationRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AnnouncementNotificationService {

    private final StoreInterestRepository storeInterestRepository;
    private final UserNotificationRepository notificationRepository;
    private final PushDeliveryService pushDeliveryService;

    public void notifyInterestedCustomers(
            Announcement announcement,
            Instant occurredAt
    ) {
        String title = limit(
                announcement.getStore().getName() + " 새 공지",
                200
        );
        String message = limit(
                announcement.getTitle() + " - " + announcement.getContent(),
                500
        );
        List<UserNotification> notifications = storeInterestRepository
                .findAllByStoreId(announcement.getStore().getId())
                .stream()
                .map(interest -> UserNotification.storeAnnouncement(
                        interest.getUser(),
                        UUID.randomUUID().toString(),
                        announcement.getStore().getId(),
                        title,
                        message,
                        occurredAt
                ))
                .toList();
        if (notifications.isEmpty()) {
            return;
        }
        List<UserNotification> saved = notificationRepository.saveAll(notifications);
        notificationRepository.flush();
        saved.forEach(pushDeliveryService::deliver);
    }

    private String limit(String value, int maxLength) {
        return value.length() <= maxLength
                ? value
                : value.substring(0, maxLength);
    }
}
