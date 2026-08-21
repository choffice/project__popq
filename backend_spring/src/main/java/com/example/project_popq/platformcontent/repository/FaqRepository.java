package com.example.project_popq.platformcontent.repository;

import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.Faq;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FaqRepository extends JpaRepository<Faq, Long>, JpaSpecificationExecutor<Faq> {

    boolean existsByAudienceAndQuestion(
        AppAudience audience,
        String question
    );

    @Query("""
            select faq
            from Faq faq
            where faq.status = com.example.project_popq.platformcontent.domain.ContentStatus.PUBLISHED
              and faq.audience in (:audience, com.example.project_popq.platformcontent.domain.AppAudience.ALL)
            order by faq.displayOrder asc, faq.id asc
            """)
    List<Faq> findPublished(@Param("audience") AppAudience audience);

}
