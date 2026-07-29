package com.example.project_popq.engagement.dto;

import com.example.project_popq.auth.dto.AuthUserResponse;

public record CustomerProfileResponse(
        AuthUserResponse user,
        long interestCount,
        long reviewCount,
        long orderCount
) {
}
