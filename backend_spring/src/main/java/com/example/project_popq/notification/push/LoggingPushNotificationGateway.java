package com.example.project_popq.notification.push;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
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
