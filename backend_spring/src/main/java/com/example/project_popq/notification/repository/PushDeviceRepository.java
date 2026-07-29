package com.example.project_popq.notification.repository;

import com.example.project_popq.notification.domain.PushDevice;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PushDeviceRepository extends JpaRepository<PushDevice, Long> {

    Optional<PushDevice> findByToken(String token);

    Optional<PushDevice> findByIdAndUserId(Long id, Long userId);

    List<PushDevice> findAllByUserIdOrderByCreatedAtDesc(Long userId);
}
