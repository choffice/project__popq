package com.example.project_popq.inquiry.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.inquiry.dto.ReadOrderMessagesRequest;
import com.example.project_popq.inquiry.dto.SendOrderMessageRequest;
import com.example.project_popq.inquiry.service.OrderMessageService;
import jakarta.validation.Valid;
import java.security.Principal;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Controller;

@Controller
@RequiredArgsConstructor
public class OrderMessageWebSocketController {

  private final CurrentUserService currentUserService;
  private final OrderMessageService orderMessageService;

  /**
   * 실제 클라이언트 SEND 경로:
   *
   * /app/orders/{orderPublicId}/chat/messages
   */
  @MessageMapping(
      "/orders/{orderPublicId}/chat/messages"
  )
  public void sendMessage(
      @DestinationVariable String orderPublicId,
      @Valid @Payload SendOrderMessageRequest request,
      Principal principal
  ) {
    Jwt jwt = requireJwt(principal);

    orderMessageService.sendRealtimeMessage(
        currentUserService.getRequired(jwt),
        orderPublicId,
        request
    );
  }

  /**
   * 실제 클라이언트 SEND 경로:
   *
   * /app/orders/{orderPublicId}/chat/read
   */
  @MessageMapping(
      "/orders/{orderPublicId}/chat/read"
  )
  public void markMessagesAsRead(
      @DestinationVariable String orderPublicId,
      @Valid @Payload ReadOrderMessagesRequest request,
      Principal principal
  ) {
    Jwt jwt = requireJwt(principal);

    orderMessageService
        .markRealtimeMessagesAsRead(
            currentUserService.getRequired(jwt),
            orderPublicId,
            request
        );
  }

  private Jwt requireJwt(
      Principal principal
  ) {
    if (
        principal
            instanceof JwtAuthenticationToken
            jwtAuthenticationToken
    ) {
      return jwtAuthenticationToken.getToken();
    }

    if (
        principal instanceof Authentication authentication
            && authentication.getPrincipal()
            instanceof Jwt jwt
    ) {
      return jwt;
    }

    throw new BusinessException(
        ErrorCode.AUTHENTICATION_REQUIRED,
        "WebSocket JWT 인증이 필요합니다."
    );
  }
}