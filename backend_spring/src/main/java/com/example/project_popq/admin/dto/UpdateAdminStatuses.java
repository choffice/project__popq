package com.example.project_popq.admin.dto;

import com.example.project_popq.seller.domain.SellerVerificationStatus;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.user.domain.UserStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public final class UpdateAdminStatuses {

    private UpdateAdminStatuses() {
    }

    public record UserStatusRequest(
            @NotNull UserStatus status,
            @Size(max = 500) String reason
    ) {
    }

    public record SellerVerificationRequest(
            @NotNull SellerVerificationStatus verificationStatus,
            @Size(max = 500) String reason
    ) {
    }

    public record StoreStatusRequest(
            @NotNull StoreStatus status,
            @Size(max = 500) String reason
    ) {
    }
}
