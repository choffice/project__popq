package com.example.project_popq.inquiry.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.domain.OrderMessage;
import com.example.project_popq.inquiry.dto.CustomerOrderUnreadMessageResponse;
import com.example.project_popq.inquiry.dto.OrderMessagePageResponse;
import com.example.project_popq.inquiry.dto.OrderMessageResponse;
import com.example.project_popq.inquiry.dto.ReadOrderMessagesRequest;
import com.example.project_popq.inquiry.dto.SellerConversationDetailResponse;
import com.example.project_popq.inquiry.dto.SellerConversationSummaryResponse;
import com.example.project_popq.inquiry.dto.SendOrderMessageRequest;
import com.example.project_popq.inquiry.repository.OrderMessageRepository;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.realtime.chat.OrderChatDomainEventPublisher;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class OrderMessageService {

  private static final int DEFAULT_MESSAGE_PAGE_SIZE = 30;
  private static final int MAX_MESSAGE_PAGE_SIZE = 100;

  private final StoreAuthorizationService storeAuthorizationService;
  private final OrderRepository orderRepository;
  private final OrderMessageRepository orderMessageRepository;
  private final OrderChatDomainEventPublisher orderChatDomainEventPublisher;
  private final EntityManager entityManager;

  @Transactional(readOnly = true)
  public List<SellerConversationSummaryResponse> findSellerConversations(
      User seller,
      Long storeId
  ) {
    requireStoreMember(
        seller.getId(),
        storeId
    );

    return orderMessageRepository
        .findLatestMessagesByStoreId(storeId)
        .stream()
        .filter(message ->
            message.getOrder().getUser() != null
        )
        .map(message ->
            SellerConversationSummaryResponse.of(
                message,
                orderMessageRepository
                    .countByOrderIdAndSenderTypeAndReadAtIsNull(
                        message.getOrder().getId(),
                        MessageSenderType.CUSTOMER
                    )
            )
        )
        .toList();
  }

  @Transactional
  public SellerConversationDetailResponse findSellerConversation(
      User seller,
      Long storeId,
      String orderPublicId
  ) {
    requireStoreMember(
        seller.getId(),
        storeId
    );

    Order order = findSellerOrder(
        storeId,
        orderPublicId
    );

    requireCustomerOrder(order);

    markMessagesAsRead(
        order,
        MessageSenderType.CUSTOMER,
        MessageSenderType.SELLER,
        null
    );

    List<OrderMessage> messages =
        orderMessageRepository
            .findAllByOrderIdOrderByCreatedAtAscIdAsc(
                order.getId()
            );

    return SellerConversationDetailResponse.of(
        order,
        messages
    );
  }

  @Transactional(readOnly = true)
  public SellerConversationDetailResponse findSellerConversationMetadata(
      User seller,
      Long storeId,
      String orderPublicId
  ) {
    requireStoreMember(
        seller.getId(),
        storeId
    );

    Order order = findSellerOrder(
        storeId,
        orderPublicId
    );

    requireCustomerOrder(order);

    return SellerConversationDetailResponse.of(
        order,
        List.of()
    );
  }

  @Transactional
  public OrderMessagePageResponse findSellerMessagePage(
      User seller,
      Long storeId,
      String orderPublicId,
      Long beforeMessageId,
      Integer size
  ) {
    requireStoreMember(
        seller.getId(),
        storeId
    );

    Order order = findSellerOrder(
        storeId,
        orderPublicId
    );

    requireCustomerOrder(order);

    markMessagesAsRead(
        order,
        MessageSenderType.CUSTOMER,
        MessageSenderType.SELLER,
        null
    );

    return findMessagePage(
        order.getId(),
        beforeMessageId,
        size
    );
  }

  @Transactional
  public OrderMessageResponse sendSellerMessage(
      User seller,
      Long storeId,
      String orderPublicId,
      SendOrderMessageRequest request
  ) {
    requireStoreMember(
        seller.getId(),
        storeId
    );

    Order order = findSellerOrder(
        storeId,
        orderPublicId
    );

    requireCustomerOrder(order);

    return saveMessage(
        order,
        seller,
        MessageSenderType.SELLER,
        request
    );
  }

  @Transactional(readOnly = true)
  public long countSellerUnreadMessages(
      User seller,
      Long storeId
  ) {
    requireStoreMember(
        seller.getId(),
        storeId
    );

    return orderMessageRepository.countUnreadByStoreId(
        storeId,
        MessageSenderType.CUSTOMER
    );
  }

  @Transactional(readOnly = true)
  public List<CustomerOrderUnreadMessageResponse>
  findCustomerUnreadMessageCounts(
      User customer
  ) {
    requireCustomer(customer);

    return orderMessageRepository
        .findUnreadCountsByCustomerUserId(
            customer.getId(),
            MessageSenderType.SELLER
        );
  }

  @Transactional
  public List<OrderMessageResponse> findCustomerMessages(
      User customer,
      String orderPublicId
  ) {
    requireCustomer(customer);

    Order order = findCustomerOrder(
        customer.getId(),
        orderPublicId
    );

    markMessagesAsRead(
        order,
        MessageSenderType.SELLER,
        MessageSenderType.CUSTOMER,
        null
    );

    return orderMessageRepository
        .findAllByOrderIdOrderByCreatedAtAscIdAsc(
            order.getId()
        )
        .stream()
        .map(OrderMessageResponse::from)
        .toList();
  }

  @Transactional
  public OrderMessagePageResponse findCustomerMessagePage(
      User customer,
      String orderPublicId,
      Long beforeMessageId,
      Integer size
  ) {
    requireCustomer(customer);

    Order order = findCustomerOrder(
        customer.getId(),
        orderPublicId
    );

    markMessagesAsRead(
        order,
        MessageSenderType.SELLER,
        MessageSenderType.CUSTOMER,
        null
    );

    return findMessagePage(
        order.getId(),
        beforeMessageId,
        size
    );
  }

  @Transactional
  public OrderMessageResponse sendCustomerMessage(
      User customer,
      String orderPublicId,
      SendOrderMessageRequest request
  ) {
    requireCustomer(customer);

    Order order = findCustomerOrder(
        customer.getId(),
        orderPublicId
    );

    return saveMessage(
        order,
        customer,
        MessageSenderType.CUSTOMER,
        request
    );
  }

  /**
   * WebSocket 메시지 전송용 공통 메서드입니다.
   *
   * 클라이언트가 senderType이나 storeId를 보내지 않아도
   * JWT 사용자 역할과 실제 주문 정보를 기준으로 서버가 판단합니다.
   */
  @Transactional
  public OrderMessageResponse sendRealtimeMessage(
      User sender,
      String orderPublicId,
      SendOrderMessageRequest request
  ) {
    if (sender.hasRole(PlatformRole.CUSTOMER)) {
      Order order = findCustomerOrder(
          sender.getId(),
          orderPublicId
      );

      return saveMessage(
          order,
          sender,
          MessageSenderType.CUSTOMER,
          request
      );
    }

    if (
        sender.hasRole(PlatformRole.SELLER)
            || sender.hasRole(PlatformRole.ADMIN)
    ) {
      Order order = findOrder(orderPublicId);

      requireCustomerOrder(order);

      requireStoreMember(
          sender.getId(),
          order.getStore().getId()
      );

      return saveMessage(
          order,
          sender,
          MessageSenderType.SELLER,
          request
      );
    }

    throw new BusinessException(
        ErrorCode.ACCESS_DENIED
    );
  }

  /**
   * WebSocket 읽음 처리용 메서드입니다.
   *
   * 마지막으로 실제 화면에 표시된 메시지 ID까지만
   * 읽음 처리합니다.
   */
  @Transactional
  public void markRealtimeMessagesAsRead(
      User reader,
      String orderPublicId,
      ReadOrderMessagesRequest request
  ) {
    if (reader.hasRole(PlatformRole.CUSTOMER)) {
      Order order = findCustomerOrder(
          reader.getId(),
          orderPublicId
      );

      markMessagesAsRead(
          order,
          MessageSenderType.SELLER,
          MessageSenderType.CUSTOMER,
          request.lastReadMessageId()
      );

      return;
    }

    if (
        reader.hasRole(PlatformRole.SELLER)
            || reader.hasRole(PlatformRole.ADMIN)
    ) {
      Order order = findOrder(orderPublicId);

      requireCustomerOrder(order);

      requireStoreMember(
          reader.getId(),
          order.getStore().getId()
      );

      markMessagesAsRead(
          order,
          MessageSenderType.CUSTOMER,
          MessageSenderType.SELLER,
          request.lastReadMessageId()
      );

      return;
    }

    throw new BusinessException(
        ErrorCode.ACCESS_DENIED
    );
  }

  private OrderMessageResponse saveMessage(
      Order order,
      User sender,
      MessageSenderType senderType,
      SendOrderMessageRequest request
  ) {
    String content =
        normalizedContent(request);

    String clientMessageId =
        request.normalizedClientMessageId();

    if (clientMessageId != null) {
      entityManager.lock(
          order,
          LockModeType.PESSIMISTIC_WRITE
      );

      OrderMessage existingMessage =
          orderMessageRepository
              .findByOrderIdAndSenderIdAndClientMessageId(
                  order.getId(),
                  sender.getId(),
                  clientMessageId
              )
              .orElse(null);

      if (existingMessage != null) {
        if (
            !existingMessage
                .getContent()
                .equals(content)
        ) {
          throw new BusinessException(
              ErrorCode.INVALID_REQUEST,
              "이미 사용된 clientMessageId에는 "
                  + "다른 메시지 내용을 사용할 수 없습니다."
          );
        }

        orderChatDomainEventPublisher
            .publishMessageCreated(
                existingMessage
            );

        return OrderMessageResponse.from(
            existingMessage
        );
      }
    }

    OrderMessage message = OrderMessage.create(
        order,
        sender,
        senderType,
        clientMessageId,
        content
    );

    OrderMessage saved =
        orderMessageRepository.saveAndFlush(
            message
        );

    orderChatDomainEventPublisher
        .publishMessageCreated(saved);

    return OrderMessageResponse.from(saved);
  }

  private OrderMessagePageResponse findMessagePage(
      Long orderId,
      Long beforeMessageId,
      Integer requestedSize
  ) {
    int pageSize =
        normalizePageSize(requestedSize);

    Pageable pageable =
        PageRequest.of(
            0,
            pageSize + 1
        );

    List<OrderMessage> messagesInDescendingOrder;

    if (beforeMessageId == null) {
      messagesInDescendingOrder =
          orderMessageRepository
              .findAllByOrderIdOrderByIdDesc(
                  orderId,
                  pageable
              );
    } else {
      if (beforeMessageId <= 0) {
        throw new BusinessException(
            ErrorCode.INVALID_REQUEST,
            "beforeMessageId는 1 이상이어야 합니다."
        );
      }

      messagesInDescendingOrder =
          orderMessageRepository
              .findAllByOrderIdAndIdLessThanOrderByIdDesc(
                  orderId,
                  beforeMessageId,
                  pageable
              );
    }

    return OrderMessagePageResponse.of(
        messagesInDescendingOrder,
        pageSize
    );
  }

  private int normalizePageSize(
      Integer requestedSize
  ) {
    if (requestedSize == null) {
      return DEFAULT_MESSAGE_PAGE_SIZE;
    }

    if (
        requestedSize < 1
            || requestedSize > MAX_MESSAGE_PAGE_SIZE
    ) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST,
          "size는 1 이상 100 이하로 입력해야 합니다."
      );
    }

    return requestedSize;
  }

  private Order findSellerOrder(
      Long storeId,
      String orderPublicId
  ) {
    return orderRepository
        .findDetailedByOrderPublicIdAndStoreId(
            orderPublicId,
            storeId
        )
        .orElseThrow(() ->
            new BusinessException(
                ErrorCode.ORDER_NOT_FOUND
            )
        );
  }

  private Order findCustomerOrder(
      Long customerUserId,
      String orderPublicId
  ) {
    return orderRepository
        .findByOrderPublicIdAndUserId(
            orderPublicId,
            customerUserId
        )
        .orElseThrow(() ->
            new BusinessException(
                ErrorCode.ORDER_NOT_FOUND
            )
        );
  }

  private Order findOrder(
      String orderPublicId
  ) {
    return orderRepository
        .findDetailedByOrderPublicId(
            orderPublicId
        )
        .orElseThrow(() ->
            new BusinessException(
                ErrorCode.ORDER_NOT_FOUND
            )
        );
  }

  private void markMessagesAsRead(
      Order order,
      MessageSenderType unreadSenderType,
      MessageSenderType readerType,
      Long lastReadMessageId
  ) {
    List<OrderMessage> unreadMessages =
        orderMessageRepository
            .findAllByOrderIdAndSenderTypeAndReadAtIsNullOrderByCreatedAtAscIdAsc(
                order.getId(),
                unreadSenderType
            )
            .stream()
            .filter(message ->
                lastReadMessageId == null
                    || message.getId()
                    <= lastReadMessageId
            )
            .toList();

    if (unreadMessages.isEmpty()) {
      return;
    }

    Instant readAt = Instant.now();

    for (OrderMessage message : unreadMessages) {
      message.markAsRead(readAt);
    }

    List<Long> readMessageIds =
        unreadMessages
            .stream()
            .map(OrderMessage::getId)
            .toList();

    orderChatDomainEventPublisher
        .publishMessagesRead(
            order,
            readerType,
            readMessageIds,
            readAt
        );
  }

  private String normalizedContent(
      SendOrderMessageRequest request
  ) {
    String content =
        request.normalizedContent();

    if (
        content.isBlank()
            || content.length() > 2000
    ) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST,
          "메시지는 공백이 아닌 "
              + "2,000자 이하로 입력해야 합니다."
      );
    }

    return content;
  }

  private void requireCustomerOrder(
      Order order
  ) {
    if (order.getUser() == null) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST,
          "로그인 고객의 주문에서만 "
              + "문의 기능을 사용할 수 있습니다."
      );
    }
  }

  private void requireCustomer(
      User customer
  ) {
    if (!customer.hasRole(PlatformRole.CUSTOMER)) {
      throw new BusinessException(
          ErrorCode.ACCESS_DENIED
      );
    }
  }

  private void requireStoreMember(
      Long sellerUserId,
      Long storeId
  ) {
    storeAuthorizationService.requireAnyRole(
        sellerUserId,
        storeId,
        StoreRole.OWNER,
        StoreRole.MANAGER,
        StoreRole.STAFF
    );
  }
}