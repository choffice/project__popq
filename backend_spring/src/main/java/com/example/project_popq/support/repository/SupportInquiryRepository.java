package com.example.project_popq.support.repository;

import com.example.project_popq.support.domain.SupportInquiry;
import com.example.project_popq.support.domain.SupportInquiryStatus;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupportInquiryRepository
    extends JpaRepository<SupportInquiry, Long> {

  @EntityGraph(attributePaths = "customer")
  List<SupportInquiry> findAllByCustomerIdOrderByCreatedAtDescIdDesc(
      Long customerUserId
  );

  @EntityGraph(attributePaths = "customer")
  List<SupportInquiry> findAllByOrderByCreatedAtDescIdDesc();

  @EntityGraph(attributePaths = "customer")
  List<SupportInquiry> findAllByStatusOrderByCreatedAtDescIdDesc(
      SupportInquiryStatus status
  );

  @EntityGraph(attributePaths = "customer")
  Optional<SupportInquiry> findWithCustomerById(Long id);

  @EntityGraph(attributePaths = "customer")
  Optional<SupportInquiry> findByIdAndCustomerId(
      Long id,
      Long customerUserId
  );

  long countByStatus(SupportInquiryStatus status);
}