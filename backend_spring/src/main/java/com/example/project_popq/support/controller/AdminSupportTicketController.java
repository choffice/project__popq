package com.example.project_popq.support.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.common.api.PageResponse;
import com.example.project_popq.support.domain.SupportCategory;
import com.example.project_popq.support.domain.SupportRequesterType;
import com.example.project_popq.support.domain.SupportTicketStatus;
import com.example.project_popq.support.dto.SupportTicketDetailResponse;
import com.example.project_popq.support.dto.SupportTicketRequest;
import com.example.project_popq.support.dto.SupportTicketSummaryResponse;
import com.example.project_popq.support.service.SupportTicketService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/support/tickets")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminSupportTicketController {

    private final CurrentUserService currentUserService;
    private final SupportTicketService service;

    @GetMapping
    public ApiResponse<PageResponse<SupportTicketSummaryResponse>> tickets(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) SupportRequesterType requesterType,
            @RequestParam(required = false) SupportCategory category,
            @RequestParam(required = false) SupportTicketStatus status
    ) {
        return ApiResponse.success(service.adminTickets(
                currentUserService.getRequired(jwt), page, size, query,
                requesterType, category, status
        ));
    }

    @GetMapping("/{ticketId}")
    public ApiResponse<SupportTicketDetailResponse> ticket(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long ticketId
    ) {
        return ApiResponse.success(service.adminTicket(
                currentUserService.getRequired(jwt), ticketId
        ));
    }

    @PostMapping("/{ticketId}/messages")
    public ApiResponse<SupportTicketDetailResponse> reply(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long ticketId,
            @Valid @RequestBody SupportTicketRequest.Message request
    ) {
        return ApiResponse.success(service.addAdminMessage(
                currentUserService.getRequired(jwt), ticketId, request
        ));
    }

    @PatchMapping("/{ticketId}/status")
    public ApiResponse<SupportTicketDetailResponse> changeStatus(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long ticketId,
            @Valid @RequestBody SupportTicketRequest.ChangeStatus request
    ) {
        return ApiResponse.success(service.changeStatus(
                currentUserService.getRequired(jwt), ticketId, request
        ));
    }
}
