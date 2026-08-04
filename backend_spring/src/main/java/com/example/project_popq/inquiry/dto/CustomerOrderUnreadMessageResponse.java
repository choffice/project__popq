package com.example.project_popq.inquiry.dto;

public record CustomerOrderUnreadMessageResponse(
    String orderPublicId,
    long unreadCount
) {
}