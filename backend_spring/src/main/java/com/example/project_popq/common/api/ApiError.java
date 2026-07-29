package com.example.project_popq.common.api;

import java.util.Map;

public record ApiError(
        String code,
        String message,
        String path,
        Map<String, Object> details
) {
    public static ApiError of(String code, String message, String path) {
        return new ApiError(code, message, path, Map.of());
    }

    public static ApiError of(
            String code,
            String message,
            String path,
            Map<String, Object> details
    ) {
        return new ApiError(code, message, path, Map.copyOf(details));
    }
}

