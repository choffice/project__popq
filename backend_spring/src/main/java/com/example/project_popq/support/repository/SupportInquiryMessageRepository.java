package com.example.project_popq.support.repository;

import com.example.project_popq.support.domain.SupportInquiryMessage;
import com.example.project_popq.support.domain.SupportMessageSenderType;

import java.util.List;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupportInquiryMessageRepository extends JpaRepository<SupportInquiryMessage, Long> {

  @EntityGraph(attributePaths = {"sender", "inquiry"})
  List<SupportInquiryMessage> findAllByInquiryIdOrderByCreatedAtAscIdAsc(
      Long supportInquiryId
  );

  @EntityGraph(attributePaths = "sender")
  List<SupportInquiryMessage> findAllByInquiryIdAndSenderTypeAndReadAtIsNullOrderByCreatedAtAscIdAsc(
      Long supportInquiryId,
      SupportMessageSenderType senderType
  );


  long countByInquiryId(Long supportInquiryId);

  long countByInquiryIdAndSenderTypeAndReadAtIsNull(
      Long supportInquiryId,
      SupportMessageSenderType senderType
  );
}