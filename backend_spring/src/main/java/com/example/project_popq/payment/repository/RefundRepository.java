package com.example.project_popq.payment.repository;

import com.example.project_popq.payment.domain.Refund;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RefundRepository extends JpaRepository<Refund, Long> {
}

