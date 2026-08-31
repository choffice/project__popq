package com.example.project_popq.support.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.common.api.PageResponse;
import com.example.project_popq.support.dto.SupportTicketDetailResponse;
import com.example.project_popq.support.dto.SupportTicketRequest;
import com.example.project_popq.support.dto.SupportTicketSummaryResponse;
import com.example.project_popq.support.service.SupportTicketService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/support/tickets")
@RequiredArgsConstructor
public class SupportTicketController {

    private final CurrentUserService currentUserService;
    private final SupportTicketService service;

    @PostMapping
    public ApiResponse<SupportTicketDetailResponse> create(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody SupportTicketRequest.Create request
    ) {
        return ApiResponse.success(service.create(currentUserService.getRequired(jwt), request));
    }

    @GetMapping
    public ApiResponse<PageResponse<SupportTicketSummaryResponse>> myTickets(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size
    ) {
        return ApiResponse.success(service.myTickets(
                currentUserService.getRequired(jwt), page, size
        ));
    }

    @GetMapping("/{ticketId}")
    public ApiResponse<SupportTicketDetailResponse> myTicket(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long ticketId
    ) {
        return ApiResponse.success(service.myTicket(
                currentUserService.getRequired(jwt), ticketId
        ));
    }

    @PostMapping("/{ticketId}/messages")
    public ApiResponse<SupportTicketDetailResponse> addMessage(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long ticketId,
            @Valid @RequestBody SupportTicketRequest.Message request
    ) {
        return ApiResponse.success(service.addRequesterMessage(
                currentUserService.getRequired(jwt), ticketId, request
        ));
    }

    @PostMapping("/{ticketId}/read")
    public ApiResponse<SupportTicketDetailResponse> markAsRead(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long ticketId
    ) {
        return ApiResponse.success(service.markRequesterRead(
                currentUserService.getRequired(jwt), ticketId
        ));
    }
}
