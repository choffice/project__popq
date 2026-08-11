package com.example.project_popq.announcement.repository;

import com.example.project_popq.announcement.domain.Announcement;
import com.example.project_popq.announcement.domain.AnnouncementStatus;
import java.util.List;
import java.util.Optional;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AnnouncementRepository
        extends JpaRepository<Announcement, Long> {

    @Query("""
            select announcement
            from Announcement announcement
            where announcement.store.id = :storeId
            order by announcement.pinned desc,
                     case when announcement.pinned = true
                          then announcement.publishedAt end desc,
                     case when announcement.pinned = false
                          then announcement.createdAt end desc,
                     announcement.id desc
            """)
    List<Announcement> findAllForSeller(@Param("storeId") Long storeId);

    Optional<Announcement> findByIdAndStoreId(Long id, Long storeId);

    List<Announcement> findAllByStoreIdAndStatusOrderByPinnedDescPublishedAtDescIdDesc(
            Long storeId,
            AnnouncementStatus status
    );

    long countByStoreIdAndPinnedTrue(Long storeId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select announcement
            from Announcement announcement
            where announcement.id = :announcementId
              and announcement.store.id = :storeId
            """)
    Optional<Announcement> findForUpdateByIdAndStoreId(
            @Param("announcementId") Long announcementId,
            @Param("storeId") Long storeId
    );

    Optional<Announcement> findByIdAndStoreIdAndStatus(
            Long id,
            Long storeId,
            AnnouncementStatus status
    );
}
