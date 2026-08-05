package com.example.project_popq.realtime.config;

import com.example.project_popq.qr.config.QrProperties;
import com.example.project_popq.realtime.security.StompSecurityInterceptor;
import java.util.LinkedHashSet;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
@EnableConfigurationProperties(RealtimeProperties.class)
@RequiredArgsConstructor
public class RealtimeConfig implements WebSocketMessageBrokerConfigurer {

    private final RealtimeProperties properties;
    private final QrProperties qrProperties;
    private final GuestSessionHandshakeInterceptor guestSessionHandshakeInterceptor;
    private final StompSecurityInterceptor stompSecurityInterceptor;

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic", "/queue");
        registry.setApplicationDestinationPrefixes("/app");
        registry.setUserDestinationPrefix("/user");
        registry.setPreservePublishOrder(true);
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws")
                .addInterceptors(guestSessionHandshakeInterceptor)
                .setAllowedOriginPatterns(allowedOriginPatterns());
    }

    String[] allowedOriginPatterns() {
        LinkedHashSet<String> allowedOriginPatterns = new LinkedHashSet<>(
                properties.allowedOriginPatterns()
        );
        allowedOriginPatterns.add(qrProperties.publicOrigin());
        return allowedOriginPatterns.toArray(String[]::new);
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(stompSecurityInterceptor);
    }
}
