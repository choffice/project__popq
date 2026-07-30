package com.example.project_popq.announcement.controller;

import com.example.project_popq.announcement.dto.AnnouncementResponse;
import com.example.project_popq.announcement.dto.ChangeAnnouncementStatusRequest;
import com.example.project_popq.announcement.dto.SaveAnnouncementRequest;
import com.example.project_popq.announcement.service.AnnouncementService;
import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller/stores/{storeId}/announcements")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerAnnouncementController {

    private final CurrentUserService currentUserService;
    private final AnnouncementService announcementService;

    @GetMapping
    public ApiResponse<List<AnnouncementResponse>> findAll(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(
                announcementService.findAll(
                        currentUserService.getRequired(jwt),
                        storeId
                )
        );
    }

    @PostMapping
    public ResponseEntity<ApiResponse<AnnouncementResponse>> create(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @Valid @RequestBody SaveAnnouncementRequest request
    ) {
        AnnouncementResponse created = announcementService.create(
                currentUserService.getRequired(jwt),
                storeId,
                request
        );
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(created));
    }

    @PatchMapping("/{announcementId}")
    public ApiResponse<AnnouncementResponse> update(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long announcementId,
            @Valid @RequestBody SaveAnnouncementRequest request
    ) {
        return ApiResponse.success(
                announcementService.update(
                        currentUserService.getRequired(jwt),
                        storeId,
                        announcementId,
                        request
                )
        );
    }

    @PatchMapping("/{announcementId}/status")
    public ApiResponse<AnnouncementResponse> changeStatus(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long storeId,
            @PathVariable Long announcementId,
            @Valid @RequestBody ChangeAnnouncementStatusRequest request
    ) {
        return ApiResponse.success(
                announcementService.changeStatus(
                        currentUserService.getRequired(jwt),
                        storeId,
                        announcementId,
                        request
                )
        );
    }
}

