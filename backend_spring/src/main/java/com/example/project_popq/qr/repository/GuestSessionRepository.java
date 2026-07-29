package com.example.project_popq.qr.repository;

import com.example.project_popq.qr.domain.GuestSession;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GuestSessionRepository extends JpaRepository<GuestSession, Long> {

    @EntityGraph(attributePaths = {
            "qrCode",
            "qrCode.store",
            "qrCode.storeTable"
    })
    Optional<GuestSession> findBySessionHash(String sessionHash);
}

