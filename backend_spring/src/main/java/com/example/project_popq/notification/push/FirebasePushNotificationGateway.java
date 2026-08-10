package com.example.project_popq.notification.push;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(
    prefix = "popq.push",
    name = "firebase-enabled",
    havingValue = "true"
)
public class FirebasePushNotificationGateway
    implements PushNotificationGateway {

  private final FirebaseApp firebaseApp;

  @Override
  public void send(PushMessage pushMessage) {
    String androidChannelId = pushMessage.data().get("androidChannelId");
    String androidSound = pushMessage.data().get("androidSound");
    boolean hasCustomAndroidSound = androidChannelId != null
        && !androidChannelId.isBlank()
        && androidSound != null
        && !androidSound.isBlank();

    AndroidConfig.Builder androidConfig = AndroidConfig.builder()
        .setPriority(AndroidConfig.Priority.HIGH);

    if (hasCustomAndroidSound) {
      androidConfig.setNotification(
          AndroidNotification.builder()
              .setChannelId(androidChannelId)
              .setSound(androidSound)
              .build()
      );
    }

    Message.Builder messageBuilder =
        Message.builder()
            .setToken(pushMessage.token())
            .putAllData(pushMessage.data())
            .setAndroidConfig(
                androidConfig.build()
            );

    if (pushMessage.alertEnabled()) {
      messageBuilder.setNotification(
          Notification.builder()
              .setTitle(pushMessage.title())
              .setBody(pushMessage.body())
              .build()
      );
    }

    String rawBadgeCount =
        pushMessage.data().get("badgeCount");

    if (rawBadgeCount != null) {
      try {
        int badgeCount = Math.max(
            0,
            Integer.parseInt(rawBadgeCount)
        );

        Aps.Builder apsBuilder =
            Aps.builder()
                .setBadge(badgeCount);

        if (!pushMessage.alertEnabled()) {
          apsBuilder.setContentAvailable(true);
        }

        messageBuilder.setApnsConfig(
            ApnsConfig.builder()
                .putHeader(
                    "apns-priority",
                    pushMessage.alertEnabled()
                        ? "10"
                        : "5"
                )
                .setAps(apsBuilder.build())
                .build()
        );
      } catch (NumberFormatException exception) {
        log.warn(
            "Invalid push badge count. value={}",
            rawBadgeCount
        );
      }
    }

    Message firebaseMessage =
        messageBuilder.build();

    try {
      String messageId = FirebaseMessaging
          .getInstance(firebaseApp)
          .send(firebaseMessage);

      log.info(
          "FCM push sent successfully. messageId={}, data={}",
          messageId,
          pushMessage.data()
      );
    } catch (FirebaseMessagingException exception) {
      log.warn(
          "FCM push delivery failed. errorCode={}, message={}",
          exception.getMessagingErrorCode(),
          exception.getMessage()
      );
    }
  }
}
