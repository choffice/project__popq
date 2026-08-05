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
public class StompSecurityInterceptor
    implements ChannelInterceptor {

    private static final String BEARER_PREFIX =
        "Bearer ";

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

        StompCommand command =
            accessor.getCommand();

        if (command == null) {
            return message;
        }

        /*
         * WebSocket 연결 시 JWT 또는 게스트 세션으로
         * STOMP Principal을 설정합니다.
         */
        if (command == StompCommand.CONNECT) {
            accessor.setUser(
                authenticate(accessor)
            );

            return message;
        }

        /*
         * 구독 요청은 destination별 권한을 검사합니다.
         */
        if (command == StompCommand.SUBSCRIBE) {
            String destination =
                requireDestination(
                    accessor,
                    "구독 경로가 필요합니다."
                );

            subscriptionAuthorizer
                .authorizeSubscription(
                    accessor.getUser(),
                    destination
                );

            return message;
        }

        /*
         * 이전에는 모든 클라이언트 SEND 요청을 차단했지만,
         * 이제 허용된 주문 채팅 경로만 통과시킵니다.
         */
        if (command == StompCommand.SEND) {
            String destination =
                requireDestination(
                    accessor,
                    "전송 경로가 필요합니다."
                );

            subscriptionAuthorizer.authorizeSend(
                accessor.getUser(),
                destination
            );

            return message;
        }

        return message;
    }

    private Authentication authenticate(
        StompHeaderAccessor accessor
    ) {
        String authorization =
            accessor.getFirstNativeHeader(
                "Authorization"
            );

        /*
         * 구매자 및 판매자 Flutter 앱은
         * STOMP CONNECT 헤더로 JWT를 전달합니다.
         */
        if (
            authorization != null
                && authorization.startsWith(
                BEARER_PREFIX
            )
        ) {
            return authenticateJwt(
                authorization.substring(
                    BEARER_PREFIX.length()
                )
            );
        }

        /*
         * JWT가 없다면 기존 QR 게스트 세션 인증을
         * 시도합니다.
         */
        Map<String, Object> attributes =
            accessor.getSessionAttributes();

        Object rawGuestToken =
            attributes == null
                ? null
                : attributes.get(
                GUEST_SESSION_ATTRIBUTE
            );

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

    private Authentication authenticateJwt(
        String rawToken
    ) {
        Jwt jwt = jwtDecoder.decode(rawToken);

        Long userId;

        try {
            userId = Long.valueOf(
                jwt.getSubject()
            );
        } catch (NumberFormatException exception) {
            throw new AccessDeniedException(
                "유효하지 않은 JWT subject입니다."
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

        String role =
            jwt.getClaimAsString("role");

        if (
            role == null
                || role.isBlank()
        ) {
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

    private String requireDestination(
        StompHeaderAccessor accessor,
        String errorMessage
    ) {
        String destination =
            accessor.getDestination();

        if (
            destination == null
                || destination.isBlank()
        ) {
            throw new AccessDeniedException(
                errorMessage
            );
        }

        return destination;
    }
}