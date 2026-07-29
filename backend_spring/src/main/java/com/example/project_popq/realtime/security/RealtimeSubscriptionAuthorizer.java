package com.example.project_popq.realtime.security;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.realtime.messaging.GuestRealtimePrincipal;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import java.security.Principal;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@RequiredArgsConstructor
public class RealtimeSubscriptionAuthorizer {

    private static final Pattern STORE_DESTINATION = Pattern.compile(
            "^/topic/stores/(\\d+)/orders$"
    );
    private static final Pattern GUEST_ORDER_DESTINATION = Pattern.compile(
            "^/user/queue/orders/([A-Za-z0-9-]{1,40})$"
    );

    private final StoreAuthorizationService storeAuthorizationService;
    private final OrderRepository orderRepository;

    @Transactional(readOnly = true)
    public void authorize(Principal principal, String destination) {
        if (!(principal instanceof Authentication authentication)
                || !authentication.isAuthenticated()) {
            throw new AccessDeniedException("STOMP 인증이 필요합니다.");
        }

        Matcher storeMatcher = STORE_DESTINATION.matcher(destination);
        if (storeMatcher.matches()) {
            authorizeStore(authentication, Long.valueOf(storeMatcher.group(1)));
            return;
        }

        Matcher guestMatcher = GUEST_ORDER_DESTINATION.matcher(destination);
        if (guestMatcher.matches()) {
            authorizeGuestOrder(authentication, guestMatcher.group(1));
            return;
        }
        throw new AccessDeniedException("허용되지 않은 STOMP 구독 경로입니다.");
    }

    private void authorizeStore(Authentication authentication, Long storeId) {
        if (!(authentication.getPrincipal()
                instanceof org.springframework.security.oauth2.jwt.Jwt jwt)) {
            throw new AccessDeniedException("판매자 인증이 필요합니다.");
        }
        Long userId;
        try {
            userId = Long.valueOf(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new AccessDeniedException("유효하지 않은 판매자 인증입니다.");
        }
        storeAuthorizationService.requireAnyRole(
                userId,
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
    }

    private void authorizeGuestOrder(
            Authentication authentication,
            String orderPublicId
    ) {
        if (!(authentication.getPrincipal()
                instanceof GuestRealtimePrincipal guestPrincipal)) {
            throw new AccessDeniedException("게스트 인증이 필요합니다.");
        }
        Order order = orderRepository.findByOrderPublicId(orderPublicId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.ORDER_NOT_FOUND
                ));
        if (!order.belongsToGuestSession(guestPrincipal.guestSessionId())) {
            throw new AccessDeniedException("주문 구독 권한이 없습니다.");
        }
    }
}
