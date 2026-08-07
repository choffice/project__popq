package com.example.project_popq.notification.push;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@ConditionalOnProperty(
    prefix = "popq.push",
    name = "firebase-enabled",
    havingValue = "false",
    matchIfMissing = true
)
public class LoggingPushNotificationGateway
    implements PushNotificationGateway {

    @Override
    public void send(PushMessage message) {
        log.debug(
            "FCM adapter not configured; push delivery skipped. data={}",
            message.data()
        );
    }
}