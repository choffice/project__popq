package com.example.project_popq.support.repository;

import com.example.project_popq.support.domain.SupportTicket;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface SupportTicketRepository extends
        JpaRepository<SupportTicket, Long>,
        JpaSpecificationExecutor<SupportTicket> {

    Optional<SupportTicket> findByIdAndRequesterId(Long id, Long requesterId);
}
