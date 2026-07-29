package com.example.project_popq.qr.repository;

import com.example.project_popq.qr.domain.QrCode;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QrCodeRepository extends JpaRepository<QrCode, Long> {

    @EntityGraph(attributePaths = {"store", "storeTable"})
    Optional<QrCode> findByTokenHash(String tokenHash);

    @EntityGraph(attributePaths = {"store", "storeTable"})
    Optional<QrCode> findDetailedByIdAndStoreId(Long id, Long storeId);

    @EntityGraph(attributePaths = "storeTable")
    List<QrCode> findAllByStoreIdOrderByIdDesc(Long storeId);
}

