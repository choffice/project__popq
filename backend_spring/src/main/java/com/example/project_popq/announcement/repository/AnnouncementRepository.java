package com.example.project_popq.announcement.repository;

import com.example.project_popq.announcement.domain.Announcement;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AnnouncementRepository
        extends JpaRepository<Announcement, Long> {

    List<Announcement> findAllByStoreIdOrderByCreatedAtDescIdDesc(Long storeId);

    Optional<Announcement> findByIdAndStoreId(Long id, Long storeId);
}

