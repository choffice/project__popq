package com.example.project_popq.support.repository;

import com.example.project_popq.support.domain.SupportFaq;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SupportFaqRepository extends JpaRepository<SupportFaq, Long> {
  List<SupportFaq> findAllByActiveTrueOrderByDisplayOrderAscIdAsc();

  List<SupportFaq> findAllByActiveTrueAndPopularTrueOrderByDisplayOrderAscIdAsc();

  @Query("""
      select faq
      from SupportFaq faq
      where faq.active = true
        and (
          lower(faq.question) like lower(concat('%', :keyword, '%'))
          or lower(faq.answer) like lower(concat('%', :keyword, '%'))
        )
      order by faq.displayOrder asc, faq.id asc
      """)
  List<SupportFaq> searchActiveFaqs(
      @Param("keyword") String keyword
  );
}