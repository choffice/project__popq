package com.example.project_popq.admin.dto;

import com.example.project_popq.seller.domain.SellerVerificationStatus;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.user.domain.UserStatus;
import jakarta.validation.constraints.NotNull;

public final class UpdateAdminStatuses {

    private UpdateAdminStatuses() {
    }

    public record UserStatusRequest(@NotNull UserStatus status) {
    }

    public record SellerVerificationRequest(
            @NotNull SellerVerificationStatus verificationStatus
    ) {
    }

    public record StoreStatusRequest(@NotNull StoreStatus status) {
    }
}
