package com.example.project_popq.support.repository;

import com.example.project_popq.support.domain.SupportMessage;
import com.example.project_popq.support.domain.SupportSenderType;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SupportMessageRepository extends JpaRepository<SupportMessage, Long> {

    interface TicketUnreadCount {
        Long getTicketId();

        long getUnreadMessageCount();
    }

    List<SupportMessage> findAllByTicketIdOrderByIdAsc(Long ticketId);

    @Query("""
            select count(m.id)
            from SupportMessage m
            where m.ticket.id = :ticketId
              and m.senderType = :senderType
              and (
                    m.ticket.requesterReadAt is null
                    or m.createdAt > m.ticket.requesterReadAt
                  )
            """)
    long countUnreadByTicket(
            @Param("ticketId") Long ticketId,
            @Param("senderType") SupportSenderType senderType
    );

    @Query("""
            select m.ticket.id as ticketId,
                   count(m.id) as unreadMessageCount
            from SupportMessage m
            where m.ticket.id in :ticketIds
              and m.senderType = :senderType
              and (
                    m.ticket.requesterReadAt is null
                    or m.createdAt > m.ticket.requesterReadAt
                  )
            group by m.ticket.id
            """)
    List<TicketUnreadCount> countUnreadByTickets(
            @Param("ticketIds") Collection<Long> ticketIds,
            @Param("senderType") SupportSenderType senderType
    );
}
