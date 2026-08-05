package com.example.project_popq.realtime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.qr.service.GuestQrService.ResolvedGuestSession;
import com.example.project_popq.realtime.config.GuestSessionHandshakeInterceptor;
import com.example.project_popq.realtime.messaging.GuestRealtimePrincipal;
import com.example.project_popq.realtime.security.RealtimeSubscriptionAuthorizer;
import com.example.project_popq.realtime.security.StompSecurityInterceptor;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

class RealtimeSecurityTests {

    @Test
    void sellerJwtIsAuthenticatedOnConnect() {
        Dependencies dependencies = dependencies();
        Jwt jwt = sellerJwt();
        when(dependencies.jwtDecoder().decode("seller-token")).thenReturn(jwt);
        User user = mock(User.class);
        when(user.isActive()).thenReturn(true);
        when(dependencies.userRepository().findById(7L))
                .thenReturn(Optional.of(user));
        StompHeaderAccessor accessor = accessor(StompCommand.CONNECT);
        accessor.setNativeHeader("Authorization", "Bearer seller-token");

        dependencies.interceptor().preSend(
                message(accessor),
                mock(MessageChannel.class)
        );

        assertThat(accessor.getUser())
                .isInstanceOf(JwtAuthenticationToken.class);
        assertThat(((Authentication) accessor.getUser()).getAuthorities())
                .extracting(Object::toString)
                .containsExactly("ROLE_SELLER");
    }

    @Test
    void guestCookieSessionIsAuthenticatedOnConnect() {
        Dependencies dependencies = dependencies();
        when(dependencies.guestQrService().resolve("guest-token"))
                .thenReturn(new ResolvedGuestSession(42L, 1L, null));
        StompHeaderAccessor accessor = accessor(StompCommand.CONNECT);
        accessor.setSessionAttributes(Map.of(
                GuestSessionHandshakeInterceptor.GUEST_SESSION_ATTRIBUTE,
                "guest-token"
        ));

        dependencies.interceptor().preSend(
                message(accessor),
                mock(MessageChannel.class)
        );

        assertThat(accessor.getUser()).isInstanceOf(Authentication.class);
        Authentication authentication = (Authentication) accessor.getUser();
        assertThat(authentication.getPrincipal())
                .isEqualTo(new GuestRealtimePrincipal(42L));
    }

    @Test
    void clientSendIsDelegatedAndUnknownSubscriptionsAreDenied() {
        Dependencies dependencies = dependencies();
        StompHeaderAccessor send = accessor(StompCommand.SEND);
        send.setDestination("/app/orders");
        dependencies.interceptor().preSend(
                message(send),
                mock(MessageChannel.class)
        );
        verify(dependencies.subscriptionAuthorizer()).authorizeSend(
                null,
                "/app/orders"
        );

        RealtimeSubscriptionAuthorizer authorizer =
                new RealtimeSubscriptionAuthorizer(
                        mock(StoreAuthorizationService.class),
                        mock(OrderRepository.class)
                );
        Authentication guest = guestAuthentication(42L);
        assertThatThrownBy(() -> authorizer.authorizeSubscription(
                guest,
                "/topic/anything"
        )).isInstanceOf(AccessDeniedException.class);
    }

    @Test
    void sellerStoreAndGuestOrderSubscriptionsAreScoped() {
        StoreAuthorizationService storeAuthorizationService = mock(
                StoreAuthorizationService.class
        );
        OrderRepository orderRepository = mock(OrderRepository.class);
        RealtimeSubscriptionAuthorizer authorizer =
                new RealtimeSubscriptionAuthorizer(
                        storeAuthorizationService,
                        orderRepository
                );

        authorizer.authorizeSubscription(
                new JwtAuthenticationToken(
                        sellerJwt(),
                        List.of(new SimpleGrantedAuthority("ROLE_SELLER"))
                ),
                "/topic/stores/15/orders"
        );
        verify(storeAuthorizationService).requireAnyRole(
                7L,
                15L,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );

        Order ownedOrder = mock(Order.class);
        when(ownedOrder.belongsToGuestSession(42L)).thenReturn(true);
        when(orderRepository.findByOrderPublicId("owned-order"))
                .thenReturn(Optional.of(ownedOrder));
        authorizer.authorizeSubscription(
                guestAuthentication(42L),
                "/user/queue/orders/owned-order"
        );

        when(ownedOrder.belongsToGuestSession(99L)).thenReturn(false);
        assertThatThrownBy(() -> authorizer.authorizeSubscription(
                guestAuthentication(99L),
                "/user/queue/orders/owned-order"
        )).isInstanceOf(AccessDeniedException.class);
    }

    private Dependencies dependencies() {
        JwtDecoder jwtDecoder = mock(JwtDecoder.class);
        UserRepository userRepository = mock(UserRepository.class);
        GuestQrService guestQrService = mock(GuestQrService.class);
        RealtimeSubscriptionAuthorizer authorizer = mock(
                RealtimeSubscriptionAuthorizer.class
        );
        return new Dependencies(
                jwtDecoder,
                userRepository,
                guestQrService,
                authorizer,
                new StompSecurityInterceptor(
                        jwtDecoder,
                        userRepository,
                        guestQrService,
                        authorizer
                )
        );
    }

    private Jwt sellerJwt() {
        return Jwt.withTokenValue("seller-token")
                .header("alg", "HS256")
                .subject("7")
                .issuedAt(Instant.parse("2026-07-29T00:00:00Z"))
                .expiresAt(Instant.parse("2027-07-29T00:00:00Z"))
                .claim("role", "SELLER")
                .build();
    }

    private Authentication guestAuthentication(Long guestSessionId) {
        return UsernamePasswordAuthenticationToken.authenticated(
                new GuestRealtimePrincipal(guestSessionId),
                "",
                List.of(new SimpleGrantedAuthority("ROLE_GUEST"))
        );
    }

    private StompHeaderAccessor accessor(StompCommand command) {
        StompHeaderAccessor accessor = StompHeaderAccessor.create(command);
        accessor.setLeaveMutable(true);
        return accessor;
    }

    private Message<byte[]> message(StompHeaderAccessor accessor) {
        return MessageBuilder.createMessage(
                new byte[0],
                accessor.getMessageHeaders()
        );
    }

    private record Dependencies(
            JwtDecoder jwtDecoder,
            UserRepository userRepository,
            GuestQrService guestQrService,
            RealtimeSubscriptionAuthorizer subscriptionAuthorizer,
            StompSecurityInterceptor interceptor
    ) {
    }
}
