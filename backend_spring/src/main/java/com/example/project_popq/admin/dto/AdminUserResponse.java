package com.example.project_popq.admin.dto;

import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.domain.UserStatus;
import java.time.Instant;
import java.util.Set;

public record AdminUserResponse(
        Long userId,
        String email,
        String name,
        PlatformRole role,
        Set<PlatformRole> roles,
        UserStatus status,
        Instant createdAt
) {
    public static AdminUserResponse from(User user) {
        return new AdminUserResponse(
                user.getId(),
                user.getEmail(),
                user.getName(),
                user.getRole(),
                Set.copyOf(user.getRoles()),
                user.getStatus(),
                user.getCreatedAt()
        );
    }
}
