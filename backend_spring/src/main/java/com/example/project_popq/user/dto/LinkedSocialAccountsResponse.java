package com.example.project_popq.user.dto;

import java.util.List;

public record LinkedSocialAccountsResponse(
        List<String> providers
) {
}
