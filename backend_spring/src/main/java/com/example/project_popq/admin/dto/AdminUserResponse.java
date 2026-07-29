package com.example.project_popq.admin.dto;

import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.domain.UserStatus;
import java.time.Instant;

public record AdminUserResponse(
        Long userId,
        String email,
        String name,
        PlatformRole role,
        UserStatus status,
        Instant createdAt
) {
    public static AdminUserResponse from(User user) {
        return new AdminUserResponse(
                user.getId(),
                user.getEmail(),
                user.getName(),
                user.getRole(),
                user.getStatus(),
                user.getCreatedAt()
        );
    }
}
