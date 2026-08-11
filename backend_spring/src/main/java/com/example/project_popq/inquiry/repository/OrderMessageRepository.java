package com.example.project_popq.inquiry.repository;

import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.domain.OrderMessage;
import com.example.project_popq.inquiry.dto.CustomerOrderUnreadMessageResponse;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface OrderMessageRepository
    extends JpaRepository<OrderMessage, Long> {

  @EntityGraph(attributePaths = "sender")
  List<OrderMessage> findAllByOrderIdOrderByCreatedAtAscIdAsc(
      Long orderId
  );

  @EntityGraph(attributePaths = "sender")
  List<OrderMessage> findAllByOrderIdOrderByIdDesc(
      Long orderId,
      Pageable pageable
  );

  @EntityGraph(attributePaths = "sender")
  List<OrderMessage> findAllByOrderIdAndIdLessThanOrderByIdDesc(
      Long orderId,
      Long beforeMessageId,
      Pageable pageable
  );

  @EntityGraph(attributePaths = "sender")
  List<OrderMessage>
  findAllByOrderIdAndSenderTypeAndReadAtIsNullOrderByCreatedAtAscIdAsc(
      Long orderId,
      MessageSenderType senderType
  );

  /**
   * 같은 주문에서 같은 사용자가 같은 clientMessageId로
   * 이미 저장한 메시지가 있는지 확인합니다.
   *
   * WebSocket 전송 후 응답을 받지 못해 REST로 재전송하거나,
   * 사용자가 재전송 버튼을 여러 번 누르는 상황에서 사용합니다.
   */
  @EntityGraph(
      attributePaths = {
          "order",
          "sender"
      }
  )
  Optional<OrderMessage>
  findByOrderIdAndSenderIdAndClientMessageId(
      Long orderId,
      Long senderUserId,
      String clientMessageId
  );

  Optional<OrderMessage> findFirstByOrderIdOrderByCreatedAtDescIdDesc(
      Long orderId
  );

  long countByOrderIdAndSenderTypeAndReadAtIsNull(
      Long orderId,
      MessageSenderType senderType
  );

  @Query("""
      select count(message)
      from OrderMessage message
      where message.order.store.id = :storeId
        and message.senderType = :senderType
        and message.readAt is null
      """)
  long countUnreadByStoreId(
      @Param("storeId") Long storeId,
      @Param("senderType") MessageSenderType senderType
  );

  @Query("""
      select message.order.store.id, count(message)
      from OrderMessage message
      where message.order.store.id in :storeIds
        and message.senderType = :senderType
        and message.readAt is null
      group by message.order.store.id
      """)
  List<Object[]> countUnreadByStoreIds(
      @Param("storeIds") List<Long> storeIds,
      @Param("senderType") MessageSenderType senderType
  );

  @EntityGraph(
      attributePaths = {
          "order",
          "order.store",
          "order.user",
          "sender"
      }
  )
  @Query("""
      select message
      from OrderMessage message
      where message.order.store.id in :storeIds
        and exists (
              select unread.id
              from OrderMessage unread
              where unread.order.id = message.order.id
                and unread.senderType = :customerSenderType
                and unread.readAt is null
        )
        and not exists (
              select newer.id
              from OrderMessage newer
              where newer.order.id = message.order.id
                and (
                      newer.createdAt > message.createdAt
                      or (newer.createdAt = message.createdAt and newer.id > message.id)
                )
        )
      order by message.createdAt desc, message.id desc
      """)
  List<OrderMessage> findLatestUnreadConversationsByStoreIds(
      @Param("storeIds") List<Long> storeIds,
      @Param("customerSenderType") MessageSenderType customerSenderType,
      Pageable pageable
  );

  @Query("""
      select new com.example.project_popq.inquiry.dto.CustomerOrderUnreadMessageResponse(
          message.order.orderPublicId,
          count(message)
      )
      from OrderMessage message
      where message.order.user.id = :customerUserId
        and message.senderType = :senderType
        and message.readAt is null
      group by message.order.id, message.order.orderPublicId
      """)
  List<CustomerOrderUnreadMessageResponse> findUnreadCountsByCustomerUserId(
      @Param("customerUserId") Long customerUserId,
      @Param("senderType") MessageSenderType senderType
  );

  @Query("""
    select count(message)
    from OrderMessage message
    where message.order.user.id = :customerUserId
      and message.senderType = :senderType
      and message.readAt is null
    """)
  long countUnreadByCustomerUserId(
      @Param("customerUserId") Long customerUserId,
      @Param("senderType") MessageSenderType senderType
  );

  @EntityGraph(
      attributePaths = {
          "order",
          "order.user",
          "sender"
      }
  )
  @Query("""
      select message
      from OrderMessage message
      where message.order.store.id = :storeId
        and not exists (
              select newerMessage.id
              from OrderMessage newerMessage
              where newerMessage.order.id = message.order.id
                and (
                      newerMessage.createdAt > message.createdAt
                      or (
                          newerMessage.createdAt = message.createdAt
                          and newerMessage.id > message.id
                      )
                )
        )
      order by message.createdAt desc, message.id desc
      """)
  List<OrderMessage> findLatestMessagesByStoreId(
      @Param("storeId") Long storeId
  );
}
