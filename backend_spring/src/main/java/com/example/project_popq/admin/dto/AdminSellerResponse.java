package com.example.project_popq.admin.dto;

import com.example.project_popq.seller.domain.SellerProfile;
import com.example.project_popq.seller.domain.SellerVerificationStatus;
import com.example.project_popq.user.domain.UserStatus;
import java.time.Instant;

public record AdminSellerResponse(
        Long sellerProfileId,
        Long userId,
        String email,
        String name,
        String businessName,
        String businessRegistrationNumber,
        SellerVerificationStatus verificationStatus,
        UserStatus userStatus,
        Instant createdAt
) {
    public static AdminSellerResponse from(SellerProfile profile) {
        return new AdminSellerResponse(
                profile.getId(),
                profile.getUser().getId(),
                profile.getUser().getEmail(),
                profile.getUser().getName(),
                profile.getBusinessName(),
                profile.getBusinessRegistrationNumber(),
                profile.getVerificationStatus(),
                profile.getUser().getStatus(),
                profile.getCreatedAt()
        );
    }
}
