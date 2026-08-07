package com.example.project_popq.notification.push;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

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
    Message firebaseMessage = Message.builder()
        .setToken(pushMessage.token())
        .setNotification(
            Notification.builder()
                .setTitle(pushMessage.title())
                .setBody(pushMessage.body())
                .build()
        )
        .putAllData(pushMessage.data())
        .setAndroidConfig(
            AndroidConfig.builder()
                .setPriority(AndroidConfig.Priority.HIGH)
                .build()
        )
        .build();

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