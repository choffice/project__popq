package com.example.project_popq.realtime.config;

import static com.example.project_popq.qr.controller.PublicQrController.GUEST_SESSION_COOKIE;

import jakarta.servlet.http.Cookie;
import java.util.Map;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

@Component
public class GuestSessionHandshakeInterceptor implements HandshakeInterceptor {

    public static final String GUEST_SESSION_ATTRIBUTE =
            "POPQ_GUEST_SESSION_TOKEN";

    @Override
    public boolean beforeHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Map<String, Object> attributes
    ) {
        if (request instanceof ServletServerHttpRequest servletRequest) {
            Cookie[] cookies = servletRequest.getServletRequest().getCookies();
            if (cookies != null) {
                for (Cookie cookie : cookies) {
                    if (GUEST_SESSION_COOKIE.equals(cookie.getName())) {
                        attributes.put(
                                GUEST_SESSION_ATTRIBUTE,
                                cookie.getValue()
                        );
                        break;
                    }
                }
            }
        }
        return true;
    }

    @Override
    public void afterHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Exception exception
    ) {
    }
}
