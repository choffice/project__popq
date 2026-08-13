package com.example.project_popq.platformcontent.repository;

import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.PlatformAnnouncement;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PlatformAnnouncementRepository extends
        JpaRepository<PlatformAnnouncement, Long>,
        JpaSpecificationExecutor<PlatformAnnouncement> {

    @Query("""
            select announcement
            from PlatformAnnouncement announcement
            where announcement.status = com.example.project_popq.platformcontent.domain.ContentStatus.PUBLISHED
              and announcement.audience in (:audience, com.example.project_popq.platformcontent.domain.AppAudience.ALL)
              and (announcement.publishStartAt is null or announcement.publishStartAt <= :now)
              and (announcement.publishEndAt is null or announcement.publishEndAt > :now)
            order by announcement.publishStartAt desc, announcement.id desc
            """)
    List<PlatformAnnouncement> findPublished(
            @Param("audience") AppAudience audience,
            @Param("now") Instant now
    );

    @Query("""
            select announcement
            from PlatformAnnouncement announcement
            where announcement.id = :id
              and announcement.status = com.example.project_popq.platformcontent.domain.ContentStatus.PUBLISHED
              and announcement.audience in (:audience, com.example.project_popq.platformcontent.domain.AppAudience.ALL)
              and (announcement.publishStartAt is null or announcement.publishStartAt <= :now)
              and (announcement.publishEndAt is null or announcement.publishEndAt > :now)
            """)
    Optional<PlatformAnnouncement> findPublishedById(
            @Param("id") Long id,
            @Param("audience") AppAudience audience,
            @Param("now") Instant now
    );
}
