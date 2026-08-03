package com.example.project_popq.auth.dto;

public record AckResponse(boolean success) {

    public static AckResponse ok() {
        return new AckResponse(true);
    }
}
