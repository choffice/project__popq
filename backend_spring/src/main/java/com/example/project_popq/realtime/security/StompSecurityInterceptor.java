package com.example.project_popq.realtime.security;

import static com.example.project_popq.realtime.config.GuestSessionHandshakeInterceptor.GUEST_SESSION_ATTRIBUTE;

import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import com.example.project_popq.realtime.messaging.GuestRealtimePrincipal;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class StompSecurityInterceptor implements ChannelInterceptor {

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtDecoder jwtDecoder;
    private final UserRepository userRepository;
    private final GuestQrService guestQrService;
    private final RealtimeSubscriptionAuthorizer subscriptionAuthorizer;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(
                message,
                StompHeaderAccessor.class
        );
        if (accessor == null) {
            return message;
        }
        StompCommand command = accessor.getCommand();
        if (command == null) {
            return message;
        }
        if (command == StompCommand.CONNECT) {
            accessor.setUser(authenticate(accessor));
            return message;
        }
        if (command == StompCommand.SUBSCRIBE) {
            String destination = accessor.getDestination();
            if (destination == null) {
                throw new AccessDeniedException("구독 경로가 필요합니다.");
            }
            subscriptionAuthorizer.authorize(
                    accessor.getUser(),
                    destination
            );
            return message;
        }
        if (command == StompCommand.SEND) {
            throw new AccessDeniedException("클라이언트 메시지 전송은 허용되지 않습니다.");
        }
        return message;
    }

    private Authentication authenticate(StompHeaderAccessor accessor) {
        String authorization = accessor.getFirstNativeHeader("Authorization");
        if (authorization != null && authorization.startsWith(BEARER_PREFIX)) {
            return authenticateJwt(
                    authorization.substring(BEARER_PREFIX.length())
            );
        }

        Map<String, Object> attributes = accessor.getSessionAttributes();
        Object rawGuestToken = attributes == null
                ? null
                : attributes.get(GUEST_SESSION_ATTRIBUTE);
        if (!(rawGuestToken instanceof String token) || token.isBlank()) {
            throw new AccessDeniedException("STOMP 인증 정보가 없습니다.");
        }
        ResolvedGuestSession session = guestQrService.resolve(token);
        GuestRealtimePrincipal principal = new GuestRealtimePrincipal(
                session.guestSessionId()
        );
        return UsernamePasswordAuthenticationToken.authenticated(
                principal,
                "",
                List.of(new SimpleGrantedAuthority("ROLE_GUEST"))
        );
    }

    private Authentication authenticateJwt(String rawToken) {
        Jwt jwt = jwtDecoder.decode(rawToken);
        Long userId;
        try {
            userId = Long.valueOf(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new AccessDeniedException("유효하지 않은 JWT subject입니다.");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AccessDeniedException(
                        "사용자를 찾을 수 없습니다."
                ));
        if (!user.isActive()) {
            throw new AccessDeniedException("비활성화된 사용자입니다.");
        }
        String role = jwt.getClaimAsString("role");
        if (role == null || role.isBlank()) {
            throw new AccessDeniedException("JWT 역할 정보가 없습니다.");
        }
        return new JwtAuthenticationToken(
                jwt,
                List.of(new SimpleGrantedAuthority("ROLE_" + role))
        );
    }
}
