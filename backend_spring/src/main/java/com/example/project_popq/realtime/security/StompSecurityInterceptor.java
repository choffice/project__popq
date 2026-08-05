package com.example.project_popq.realtime.security;

import static com.example.project_popq.realtime.config.GuestSessionHandshakeInterceptor.GUEST_SESSION_ATTRIBUTE;

import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import com.example.project_popq.realtime.messaging.GuestRealtimePrincipal;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.security.Principal;
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
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class StompSecurityInterceptor
    implements ChannelInterceptor {

    private static final String BEARER_PREFIX =
        "Bearer ";

    private static final String STOMP_AUTH_ATTRIBUTE =
        "POPQ_STOMP_AUTHENTICATION";

    private final JwtDecoder jwtDecoder;
    private final UserRepository userRepository;
    private final GuestQrService guestQrService;
    private final RealtimeSubscriptionAuthorizer
        subscriptionAuthorizer;

    @Override
    public Message<?> preSend(
        Message<?> message,
        MessageChannel channel
    ) {
        StompHeaderAccessor accessor =
            MessageHeaderAccessor.getAccessor(
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
            Authentication authentication =
                authenticate(accessor);

            accessor.setUser(authentication);
            saveAuthentication(
                accessor,
                authentication
            );

            return message;
        }

        Principal principal = resolvePrincipal(accessor);

        if (command == StompCommand.SUBSCRIBE) {
            String destination = requireDestination(
                accessor,
                "구독 경로가 필요합니다."
            );

            subscriptionAuthorizer
                .authorizeSubscription(
                    principal,
                    destination
                );

            return message;
        }

        if (command == StompCommand.SEND) {
            String destination = requireDestination(
                accessor,
                "전송 경로가 필요합니다."
            );

            subscriptionAuthorizer.authorizeSend(
                principal,
                destination
            );

            return message;
        }

        return message;
    }

    private Authentication authenticate(
        StompHeaderAccessor accessor
    ) {
        String authorization = readAuthorization(accessor);

        if (
            authorization != null
                && authorization.regionMatches(
                true,
                0,
                BEARER_PREFIX,
                0,
                BEARER_PREFIX.length()
            )
        ) {
            String rawToken = authorization
                .substring(BEARER_PREFIX.length())
                .trim();

            if (rawToken.isEmpty()) {
                throw new AccessDeniedException(
                    "STOMP JWT가 비어 있습니다."
                );
            }

            return authenticateJwt(rawToken);
        }

        Map<String, Object> attributes =
            accessor.getSessionAttributes();

        Object rawGuestToken = attributes == null
            ? null
            : attributes.get(GUEST_SESSION_ATTRIBUTE);

        if (
            !(rawGuestToken instanceof String token)
                || token.isBlank()
        ) {
            throw new AccessDeniedException(
                "STOMP 인증 정보가 없습니다."
            );
        }

        ResolvedGuestSession session =
            guestQrService.resolve(token);

        GuestRealtimePrincipal principal =
            new GuestRealtimePrincipal(
                session.guestSessionId()
            );

        return UsernamePasswordAuthenticationToken
            .authenticated(
                principal,
                "",
                List.of(
                    new SimpleGrantedAuthority(
                        "ROLE_GUEST"
                    )
                )
            );
    }

    private String readAuthorization(
        StompHeaderAccessor accessor
    ) {
        String authorization =
            accessor.getFirstNativeHeader(
                "Authorization"
            );

        if (
            authorization == null
                || authorization.isBlank()
        ) {
            authorization =
                accessor.getFirstNativeHeader(
                    "authorization"
                );
        }

        return authorization == null
            ? null
            : authorization.trim();
    }

    private Authentication authenticateJwt(
        String rawToken
    ) {
        final Jwt jwt;

        try {
            jwt = jwtDecoder.decode(rawToken);
        } catch (JwtException exception) {
            throw new AccessDeniedException(
                "유효하지 않거나 만료된 STOMP JWT입니다.",
                exception
            );
        }

        Long userId;

        try {
            userId = Long.valueOf(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new AccessDeniedException(
                "유효하지 않은 JWT subject입니다.",
                exception
            );
        }

        User user = userRepository
            .findById(userId)
            .orElseThrow(() ->
                new AccessDeniedException(
                    "사용자를 찾을 수 없습니다."
                )
            );

        if (!user.isActive()) {
            throw new AccessDeniedException(
                "비활성화된 사용자입니다."
            );
        }

        String role = jwt.getClaimAsString("role");

        if (role == null || role.isBlank()) {
            throw new AccessDeniedException(
                "JWT 역할 정보가 없습니다."
            );
        }

        return new JwtAuthenticationToken(
            jwt,
            List.of(
                new SimpleGrantedAuthority(
                    "ROLE_" + role
                )
            )
        );
    }

    private void saveAuthentication(
        StompHeaderAccessor accessor,
        Authentication authentication
    ) {
        Map<String, Object> attributes =
            accessor.getSessionAttributes();

        if (attributes != null) {
            attributes.put(
                STOMP_AUTH_ATTRIBUTE,
                authentication
            );
        }
    }

    private Principal resolvePrincipal(
        StompHeaderAccessor accessor
    ) {
        Principal principal = accessor.getUser();

        if (principal != null) {
            return principal;
        }

        Map<String, Object> attributes =
            accessor.getSessionAttributes();

        Object storedAuthentication = attributes == null
            ? null
            : attributes.get(STOMP_AUTH_ATTRIBUTE);

        if (
            storedAuthentication
                instanceof Authentication authentication
        ) {
            accessor.setUser(authentication);
            return authentication;
        }

        throw new AccessDeniedException(
            "STOMP 연결 인증 정보가 유지되지 않았습니다."
        );
    }

    private String requireDestination(
        StompHeaderAccessor accessor,
        String errorMessage
    ) {
        String destination = accessor.getDestination();

        if (
            destination == null
                || destination.isBlank()
        ) {
            throw new AccessDeniedException(errorMessage);
        }

        return destination;
    }
}