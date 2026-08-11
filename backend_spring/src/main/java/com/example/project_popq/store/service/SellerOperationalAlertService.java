package com.example.project_popq.store.service;

import com.example.project_popq.activity.service.CustomerActivityService;
import com.example.project_popq.engagement.domain.ReviewStatus;
import com.example.project_popq.engagement.dto.ReviewResponse;
import com.example.project_popq.engagement.repository.ReviewRepository;
import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.domain.OrderMessage;
import com.example.project_popq.inquiry.repository.OrderMessageRepository;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.dto.OrderResponse;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMemberStatus;
import com.example.project_popq.store.dto.SellerOperationalAlertsResponse;
import com.example.project_popq.store.dto.SellerOperationalAlertsResponse.ChatAlertResponse;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.user.domain.User;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SellerOperationalAlertService {

    private final StoreMemberRepository storeMemberRepository;
    private final OrderRepository orderRepository;
    private final OrderMessageRepository orderMessageRepository;
    private final ReviewRepository reviewRepository;
    private final CustomerActivityService customerActivityService;

    @Transactional(readOnly = true)
    public SellerOperationalAlertsResponse find(User user, int requestedLimit) {
        int limit = Math.max(1, Math.min(requestedLimit, 30));
        List<Long> storeIds = storeMemberRepository
                .findAllByUserIdAndStatusOrderByIdAsc(
                        user.getId(),
                        StoreMemberStatus.ACTIVE
                )
                .stream()
                .map(member -> member.getStore())
                .filter(Store::isActive)
                .map(Store::getId)
                .toList();
        if (storeIds.isEmpty()) {
            return new SellerOperationalAlertsResponse(
                    List.of(),
                    List.of(),
                    List.of()
            );
        }

        PageRequest page = PageRequest.of(0, limit);
        List<OrderResponse> orders = orderRepository
                .findAllByStoreIdInAndStatusOrderByCreatedAtDesc(
                        storeIds,
                        OrderStatus.PLACED,
                        page
                )
                .stream()
                .map(OrderResponse::from)
                .toList();
        List<ChatAlertResponse> chats = orderMessageRepository
                .findLatestUnreadConversationsByStoreIds(
                        storeIds,
                        MessageSenderType.CUSTOMER,
                        page
                )
                .stream()
                .map(this::toChatAlert)
                .toList();
        List<ReviewResponse> reviews = reviewRepository
                .findAllByStoreIdInAndStatusAndSellerReplyIsNullOrderByCreatedAtDesc(
                        storeIds,
                        ReviewStatus.ACTIVE,
                        page
                )
                .stream()
                .map(review -> ReviewResponse.from(
                        review,
                        customerActivityService.getBadgeTier(
                                review.getUser().getId()
                        )
                ))
                .toList();
        return new SellerOperationalAlertsResponse(orders, chats, reviews);
    }

    private ChatAlertResponse toChatAlert(OrderMessage message) {
        return new ChatAlertResponse(
                message.getOrder().getStore().getId(),
                message.getOrder().getStore().getName(),
                message.getOrder().getOrderPublicId(),
                message.getOrder().getUser() == null
                        ? "비회원 고객"
                        : message.getOrder().getUser().getName(),
                message.getContent(),
                message.getCreatedAt()
        );
    }
}
