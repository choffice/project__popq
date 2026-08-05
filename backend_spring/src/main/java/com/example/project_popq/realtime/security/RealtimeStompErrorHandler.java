package com.example.project_popq.realtime.security;

import java.nio.charset.StandardCharsets;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.stereotype.Component;
import org.springframework.util.MimeTypeUtils;
import org.springframework.web.socket.messaging.StompSubProtocolErrorHandler;

@Slf4j
@Component
public class RealtimeStompErrorHandler
    extends StompSubProtocolErrorHandler {

  @Override
  protected Message<byte[]> handleInternal(
      StompHeaderAccessor errorHeaderAccessor,
      byte[] errorPayload,
      Throwable cause,
      StompHeaderAccessor clientHeaderAccessor
  ) {
    Throwable rootCause = unwrap(cause);
    String errorMessage = resolveMessage(rootCause);

    log.warn(
        "STOMP 처리 오류: command={}, destination={}, message={}",
        clientHeaderAccessor == null
            ? null
            : clientHeaderAccessor.getCommand(),
        clientHeaderAccessor == null
            ? null
            : clientHeaderAccessor.getDestination(),
        errorMessage,
        rootCause
    );

    errorHeaderAccessor.setMessage(errorMessage);
    errorHeaderAccessor.setContentType(
        MimeTypeUtils.TEXT_PLAIN
    );

    return MessageBuilder.createMessage(
        errorMessage.getBytes(StandardCharsets.UTF_8),
        errorHeaderAccessor.getMessageHeaders()
    );
  }

  private Throwable unwrap(Throwable throwable) {
    if (throwable == null) {
      return null;
    }

    Throwable current = throwable;

    while (
        current instanceof MessageDeliveryException
            && current.getCause() != null
    ) {
      current = current.getCause();
    }

    return current;
  }

  private String resolveMessage(Throwable throwable) {
    if (throwable == null) {
      return "알 수 없는 STOMP 오류가 발생했습니다.";
    }

    String message = throwable.getMessage();

    if (message == null || message.isBlank()) {
      return throwable.getClass().getSimpleName();
    }

    return message;
  }
}