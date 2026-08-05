package com.example.project_popq.realtime.security;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.realtime.messaging.GuestRealtimePrincipal;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.PlatformRole;
import java.security.Principal;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class RealtimeSubscriptionAuthorizer {

    /**
     * 기존 판매자 주문 실시간 구독 경로입니다.
     *
     * /topic/stores/{storeId}/orders
     */
    private static final Pattern STORE_ORDER_DESTINATION =
        Pattern.compile(
            "^/topic/stores/(\\d+)/orders$"
        );

    /**
     * 판매자 고객 문의 목록 및 unread 배지 갱신용 경로입니다.
     *
     * /topic/stores/{storeId}/chat
     */
    private static final Pattern STORE_CHAT_DESTINATION =
        Pattern.compile(
            "^/topic/stores/(\\d+)/chat$"
        );

    /**
     * 구매자와 판매자가 채팅 상세 화면에서 구독하는 경로입니다.
     *
     * /topic/orders/{orderPublicId}/chat
     */
    private static final Pattern ORDER_CHAT_DESTINATION =
        Pattern.compile(
            "^/topic/orders/"
                + "([A-Za-z0-9-]{1,40})"
                + "/chat$"
        );

    /**
     * 구매자 개인 unread 갱신 이벤트 경로입니다.
     *
     * /user/queue/chat
     */
    private static final Pattern CUSTOMER_CHAT_DESTINATION =
        Pattern.compile(
            "^/user/queue/chat$"
        );

    /**
     * 기존 QR 게스트 주문 실시간 구독 경로입니다.
     *
     * /user/queue/orders/{orderPublicId}
     */
    private static final Pattern GUEST_ORDER_DESTINATION =
        Pattern.compile(
            "^/user/queue/orders/"
                + "([A-Za-z0-9-]{1,40})$"
        );

    /**
     * 채팅 클라이언트가 SEND할 수 있는 경로입니다.
     *
     * /app/orders/{orderPublicId}/chat/messages
     * /app/orders/{orderPublicId}/chat/read
     */
    private static final Pattern CHAT_SEND_DESTINATION =
        Pattern.compile(
            "^/app/orders/"
                + "([A-Za-z0-9-]{1,40})"
                + "/chat/(messages|read)$"
        );

    private final StoreAuthorizationService
        storeAuthorizationService;

    private final OrderRepository orderRepository;

    /**
     * STOMP SUBSCRIBE 명령의 destination을 검사합니다.
     */
    @Transactional(readOnly = true)
    public void authorizeSubscription(
        Principal principal,
        String destination
    ) {
        Authentication authentication =
            requireAuthentication(principal);

        Matcher storeOrderMatcher =
            STORE_ORDER_DESTINATION.matcher(
                destination
            );

        if (storeOrderMatcher.matches()) {
            authorizeStore(
                authentication,
                Long.valueOf(
                    storeOrderMatcher.group(1)
                )
            );

            return;
        }

        Matcher storeChatMatcher =
            STORE_CHAT_DESTINATION.matcher(
                destination
            );

        if (storeChatMatcher.matches()) {
            authorizeStore(
                authentication,
                Long.valueOf(
                    storeChatMatcher.group(1)
                )
            );

            return;
        }

        Matcher orderChatMatcher =
            ORDER_CHAT_DESTINATION.matcher(
                destination
            );

        if (orderChatMatcher.matches()) {
            authorizeAuthenticatedOrder(
                authentication,
                orderChatMatcher.group(1)
            );

            return;
        }

        if (
            CUSTOMER_CHAT_DESTINATION
                .matcher(destination)
                .matches()
        ) {
            authorizeCustomer(authentication);
            return;
        }

        Matcher guestMatcher =
            GUEST_ORDER_DESTINATION.matcher(
                destination
            );

        if (guestMatcher.matches()) {
            authorizeGuestOrder(
                authentication,
                guestMatcher.group(1)
            );

            return;
        }

        throw new AccessDeniedException(
            "허용되지 않은 STOMP 구독 경로입니다."
        );
    }

    /**
     * STOMP SEND 명령의 destination과 주문 권한을 검사합니다.
     */
    @Transactional(readOnly = true)
    public void authorizeSend(
        Principal principal,
        String destination
    ) {
        Authentication authentication =
            requireAuthentication(principal);

        Matcher chatSendMatcher =
            CHAT_SEND_DESTINATION.matcher(
                destination
            );

        if (!chatSendMatcher.matches()) {
            throw new AccessDeniedException(
                "허용되지 않은 STOMP 전송 경로입니다."
            );
        }

        authorizeAuthenticatedOrder(
            authentication,
            chatSendMatcher.group(1)
        );
    }

    private Authentication requireAuthentication(
        Principal principal
    ) {
        if (
            !(principal
                instanceof Authentication authentication)
                || !authentication.isAuthenticated()
        ) {
            throw new AccessDeniedException(
                "STOMP 인증이 필요합니다."
            );
        }

        return authentication;
    }

    /**
     * 판매자 사업장 채널 권한을 확인합니다.
     */
    private void authorizeStore(
        Authentication authentication,
        Long storeId
    ) {
        Jwt jwt = requireJwt(
            authentication,
            "판매자 인증이 필요합니다."
        );

        PlatformRole role = resolveRole(jwt);

        if (
            role != PlatformRole.SELLER
                && role != PlatformRole.ADMIN
        ) {
            throw new AccessDeniedException(
                "판매자 구독 권한이 없습니다."
            );
        }

        storeAuthorizationService.requireAnyRole(
            resolveUserId(jwt),
            storeId,
            StoreRole.OWNER,
            StoreRole.MANAGER,
            StoreRole.STAFF
        );
    }

    /**
     * 로그인 주문 채팅 권한을 확인합니다.
     *
     * CUSTOMER:
     * 본인의 주문만 허용합니다.
     *
     * SELLER 또는 ADMIN:
     * 해당 주문 사업장의 활성 구성원만 허용합니다.
     */
    private void authorizeAuthenticatedOrder(
        Authentication authentication,
        String orderPublicId
    ) {
        Jwt jwt = requireJwt(
            authentication,
            "로그인 사용자 인증이 필요합니다."
        );

        Long userId = resolveUserId(jwt);
        PlatformRole role = resolveRole(jwt);

        Order order = orderRepository
            .findDetailedByOrderPublicId(
                orderPublicId
            )
            .orElseThrow(() ->
                new BusinessException(
                    ErrorCode.ORDER_NOT_FOUND
                )
            );

        /*
         * QR 게스트 주문에는 로그인 고객 문의 채팅을
         * 사용할 수 없습니다.
         */
        if (order.getUser() == null) {
            throw new AccessDeniedException(
                "로그인 고객 주문만 채팅할 수 있습니다."
            );
        }

        if (role == PlatformRole.CUSTOMER) {
            if (
                !order.getUser()
                    .getId()
                    .equals(userId)
            ) {
                throw new AccessDeniedException(
                    "주문 채팅 권한이 없습니다."
                );
            }

            return;
        }

        if (
            role == PlatformRole.SELLER
                || role == PlatformRole.ADMIN
        ) {
            /*
             * 클라이언트가 전달한 storeId는 사용하지 않습니다.
             *
             * 실제 주문에 연결된 storeId를 기준으로
             * 사업장 권한을 검사합니다.
             */
            storeAuthorizationService.requireAnyRole(
                userId,
                order.getStore().getId(),
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
            );

            return;
        }

        throw new AccessDeniedException(
            "주문 채팅 권한이 없습니다."
        );
    }

    /**
     * 구매자 개인 이벤트 채널은 CUSTOMER만 허용합니다.
     */
    private void authorizeCustomer(
        Authentication authentication
    ) {
        Jwt jwt = requireJwt(
            authentication,
            "구매자 인증이 필요합니다."
        );

        if (
            resolveRole(jwt)
                != PlatformRole.CUSTOMER
        ) {
            throw new AccessDeniedException(
                "구매자 전용 구독 경로입니다."
            );
        }
    }

    /**
     * 기존 QR 게스트 주문 구독 권한을 유지합니다.
     */
    private void authorizeGuestOrder(
        Authentication authentication,
        String orderPublicId
    ) {
        if (
            !(authentication.getPrincipal()
                instanceof GuestRealtimePrincipal
                guestPrincipal)
        ) {
            throw new AccessDeniedException(
                "게스트 인증이 필요합니다."
            );
        }

        Order order = orderRepository
            .findByOrderPublicId(orderPublicId)
            .orElseThrow(() ->
                new BusinessException(
                    ErrorCode.ORDER_NOT_FOUND
                )
            );

        if (
            !order.belongsToGuestSession(
                guestPrincipal.guestSessionId()
            )
        ) {
            throw new AccessDeniedException(
                "주문 구독 권한이 없습니다."
            );
        }
    }

    private Jwt requireJwt(
        Authentication authentication,
        String errorMessage
    ) {
        if (
            !(authentication.getPrincipal()
                instanceof Jwt jwt)
        ) {
            throw new AccessDeniedException(
                errorMessage
            );
        }

        return jwt;
    }

    private Long resolveUserId(
        Jwt jwt
    ) {
        try {
            return Long.valueOf(
                jwt.getSubject()
            );
        } catch (NumberFormatException exception) {
            throw new AccessDeniedException(
                "유효하지 않은 JWT subject입니다."
            );
        }
    }

    private PlatformRole resolveRole(
        Jwt jwt
    ) {
        String rawRole =
            jwt.getClaimAsString("role");

        if (
            rawRole == null
                || rawRole.isBlank()
        ) {
            throw new AccessDeniedException(
                "JWT 역할 정보가 없습니다."
            );
        }

        try {
            return PlatformRole.valueOf(
                rawRole
            );
        } catch (IllegalArgumentException exception) {
            throw new AccessDeniedException(
                "유효하지 않은 JWT 역할입니다."
            );
        }
    }
}