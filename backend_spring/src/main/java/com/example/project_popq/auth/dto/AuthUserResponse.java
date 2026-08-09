package com.example.project_popq.auth.dto;

import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.domain.UserStatus;
import java.time.Instant;

public record AuthUserResponse(
        Long userId,
        String email,
        String name,
        String phone,
        PlatformRole role,
        UserStatus status,
        String profileImageUrl,
        Instant joinedAt
) {
    public static AuthUserResponse from(User user) {
        return new AuthUserResponse(
            user.getId(),
            user.getEmail(),
            user.getName(),
            user.getPhone(),
            user.getRole(),
            user.getStatus(),
            user.getProfileImageUrl(),
            user.getCreatedAt()
        );
    }

    public static AuthUserResponse from(
        User user,
        PlatformRole activeRole
    ) {
        return new AuthUserResponse(
            user.getId(),
            user.getEmail(),
            user.getName(),
            user.getPhone(),
            activeRole,
            user.getStatus(),
            user.getProfileImageUrl(),
            user.getCreatedAt()
        );
    }
}

