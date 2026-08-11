package com.example.project_popq.notification.service;

import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.repository.OrderMessageRepository;
import com.example.project_popq.notification.repository.UserNotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomerBadgeCountService {

  private final UserNotificationRepository userNotificationRepository;
  private final OrderMessageRepository orderMessageRepository;

  @Transactional(readOnly = true)
  public long countUnread(Long customerUserId) {
    long orderNotificationCount =
        userNotificationRepository
            .countByUserIdAndReadFalse(customerUserId);

    long chatMessageCount =
        orderMessageRepository
            .countUnreadByCustomerUserId(
                customerUserId,
                MessageSenderType.SELLER
            );

    return orderNotificationCount + chatMessageCount;
  }
}