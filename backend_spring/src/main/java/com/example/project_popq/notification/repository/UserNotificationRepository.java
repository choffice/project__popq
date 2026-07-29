package com.example.project_popq.notification.repository;

import com.example.project_popq.notification.domain.UserNotification;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserNotificationRepository
        extends JpaRepository<UserNotification, Long> {

    boolean existsByEventId(String eventId);

    List<UserNotification> findAllByUserIdOrderByOccurredAtDesc(Long userId);

    List<UserNotification> findAllByUserIdAndReadFalseOrderByOccurredAtDesc(
            Long userId
    );

    Optional<UserNotification> findByIdAndUserId(Long id, Long userId);

    long countByUserIdAndReadFalse(Long userId);
}
