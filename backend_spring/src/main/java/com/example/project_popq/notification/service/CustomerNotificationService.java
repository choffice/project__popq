package com.example.project_popq.notification.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.notification.domain.UserNotification;
import com.example.project_popq.notification.dto.NotificationResponse;
import com.example.project_popq.notification.dto.UnreadNotificationCountResponse;
import com.example.project_popq.notification.repository.UserNotificationRepository;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.realtime.event.OrderRealtimeEvent;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomerNotificationService {

    private final UserNotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final PushDeliveryService pushDeliveryService;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordOrderEvent(OrderRealtimeEvent event) {
        if (event.userId() == null
                || notificationRepository.existsByEventId(event.eventId())) {
            return;
        }
        User user = userRepository.findById(event.userId())
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.USER_NOT_FOUND
                ));
        UserNotification notification = notificationRepository.save(
                UserNotification.orderStatus(
                        user,
                        event.eventId(),
                        event.orderPublicId(),
                        titleFor(event.currentStatus()),
                        messageFor(event.currentStatus()),
                        event.occurredAt()
                )
        );
        notificationRepository.flush();
        pushDeliveryService.deliver(notification);
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> findMine(
            User user,
            boolean unreadOnly
    ) {
        requireCustomer(user);
        List<UserNotification> notifications = unreadOnly
                ? notificationRepository
                        .findAllByUserIdAndReadFalseOrderByOccurredAtDesc(
                                user.getId()
                        )
                : notificationRepository
                        .findAllByUserIdOrderByOccurredAtDesc(user.getId());
        return notifications.stream().map(NotificationResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public UnreadNotificationCountResponse unreadCount(User user) {
        requireCustomer(user);
        return new UnreadNotificationCountResponse(
                notificationRepository.countByUserIdAndReadFalse(user.getId())
        );
    }

    @Transactional
    public NotificationResponse markRead(User user, Long notificationId) {
        requireCustomer(user);
        UserNotification notification = notificationRepository
                .findByIdAndUserId(notificationId, user.getId())
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.NOTIFICATION_NOT_FOUND
                ));
        notification.markRead();
        return NotificationResponse.from(notification);
    }

    private String titleFor(OrderStatus status) {
        return switch (status) {
            case PLACED -> "주문이 접수 대기 중이에요";
            case ACCEPTED -> "스토어가 주문을 접수했어요";
            case PREPARING -> "주문 상품을 준비하고 있어요";
            case READY -> "주문 상품이 준비됐어요";
            case COMPLETED -> "주문이 완료됐어요";
            case CANCELED -> "주문이 취소됐어요";
            case REJECTED -> "스토어가 주문을 거절했어요";
            case EXPIRED -> "주문의 결제 시간이 만료됐어요";
            default -> "주문 상태가 변경됐어요";
        };
    }

    private String messageFor(OrderStatus status) {
        return switch (status) {
            case READY -> "스토어에서 상품을 수령해 주세요.";
            case COMPLETED -> "이용해 주셔서 감사합니다. 리뷰를 남겨보세요.";
            case CANCELED, REJECTED, EXPIRED ->
                    "주문 상세에서 최신 상태를 확인해 주세요.";
            default -> "주문 상세에서 진행 상태를 확인할 수 있어요.";
        };
    }

    private void requireCustomer(User user) {
        if (!user.hasRole(PlatformRole.CUSTOMER)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }
}
