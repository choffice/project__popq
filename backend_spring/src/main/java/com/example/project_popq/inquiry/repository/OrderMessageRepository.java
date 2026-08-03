package com.example.project_popq.inquiry.repository;

import com.example.project_popq.inquiry.domain.MessageSenderType;
import com.example.project_popq.inquiry.domain.OrderMessage;
import java.util.List;
import java.util.Optional;
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
  List<OrderMessage>
  findAllByOrderIdAndSenderTypeAndReadAtIsNullOrderByCreatedAtAscIdAsc(
      Long orderId,
      MessageSenderType senderType
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