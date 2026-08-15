package com.example.project_popq.raffle.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.raffle.dto.MonthlyRaffleStatusResponse;
import com.example.project_popq.raffle.service.MonthlyRaffleService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/customer/monthly-raffle")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class MonthlyRaffleController {

    private final CurrentUserService currentUserService;
    private final MonthlyRaffleService raffleService;

    @GetMapping
    public ApiResponse<MonthlyRaffleStatusResponse> getStatus(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
                raffleService.getStatus(currentUserService.getRequired(jwt))
        );
    }

    @PostMapping("/tickets")
    public ApiResponse<MonthlyRaffleStatusResponse> purchaseTicket(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ApiResponse.success(
                raffleService.purchaseTicket(currentUserService.getRequired(jwt))
        );
    }
}
