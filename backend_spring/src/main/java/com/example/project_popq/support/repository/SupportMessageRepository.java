package com.example.project_popq.support.repository;

import com.example.project_popq.support.domain.SupportMessage;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupportMessageRepository extends JpaRepository<SupportMessage, Long> {
    List<SupportMessage> findAllByTicketIdOrderByIdAsc(Long ticketId);
}
