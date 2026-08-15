package com.example.project_popq.seller.repository;

import com.example.project_popq.seller.domain.SellerProfile;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface SellerProfileRepository extends JpaRepository<SellerProfile, Long>, JpaSpecificationExecutor<SellerProfile> {

    Optional<SellerProfile> findByUserId(Long userId);

    long countByVerificationStatus(
            com.example.project_popq.seller.domain.SellerVerificationStatus status
    );
}
