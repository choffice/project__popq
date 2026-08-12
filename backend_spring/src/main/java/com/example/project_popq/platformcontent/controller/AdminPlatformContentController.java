package com.example.project_popq.platformcontent.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.common.api.PageResponse;
import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.ContentStatus;
import com.example.project_popq.platformcontent.dto.FaqRequest;
import com.example.project_popq.platformcontent.dto.FaqResponse;
import com.example.project_popq.platformcontent.dto.PlatformAnnouncementRequest;
import com.example.project_popq.platformcontent.dto.PlatformAnnouncementResponse;
import com.example.project_popq.platformcontent.service.PlatformContentService;
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
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/content")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminPlatformContentController {

    private final CurrentUserService currentUserService;
    private final PlatformContentService service;

    @GetMapping("/announcements")
    public ApiResponse<PageResponse<PlatformAnnouncementResponse>> announcements(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) AppAudience audience,
            @RequestParam(required = false) ContentStatus status
    ) {
        return ApiResponse.success(service.announcements(
                currentUserService.getRequired(jwt), page, size, query, audience, status
        ));
    }

    @PostMapping("/announcements")
    public ApiResponse<PlatformAnnouncementResponse> createAnnouncement(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody PlatformAnnouncementRequest.Save request
    ) {
        return ApiResponse.success(service.createAnnouncement(
                currentUserService.getRequired(jwt), request
        ));
    }

    @PutMapping("/announcements/{id}")
    public ApiResponse<PlatformAnnouncementResponse> updateAnnouncement(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long id,
            @Valid @RequestBody PlatformAnnouncementRequest.Save request
    ) {
        return ApiResponse.success(service.updateAnnouncement(
                currentUserService.getRequired(jwt), id, request
        ));
    }

    @PatchMapping("/announcements/{id}/status")
    public ApiResponse<PlatformAnnouncementResponse> changeAnnouncementStatus(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long id,
            @Valid @RequestBody PlatformAnnouncementRequest.ChangeStatus request
    ) {
        return ApiResponse.success(service.changeAnnouncementStatus(
                currentUserService.getRequired(jwt), id, request
        ));
    }

    @GetMapping("/faqs")
    public ApiResponse<PageResponse<FaqResponse>> faqs(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) AppAudience audience,
            @RequestParam(required = false) ContentStatus status,
            @RequestParam(required = false) String category
    ) {
        return ApiResponse.success(service.faqs(
                currentUserService.getRequired(jwt), page, size, query,
                audience, status, category
        ));
    }

    @PostMapping("/faqs")
    public ApiResponse<FaqResponse> createFaq(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody FaqRequest.Save request
    ) {
        return ApiResponse.success(service.createFaq(currentUserService.getRequired(jwt), request));
    }

    @PutMapping("/faqs/{id}")
    public ApiResponse<FaqResponse> updateFaq(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long id,
            @Valid @RequestBody FaqRequest.Save request
    ) {
        return ApiResponse.success(service.updateFaq(currentUserService.getRequired(jwt), id, request));
    }

    @PatchMapping("/faqs/{id}/status")
    public ApiResponse<FaqResponse> changeFaqStatus(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable Long id,
            @Valid @RequestBody FaqRequest.ChangeStatus request
    ) {
        return ApiResponse.success(service.changeFaqStatus(
                currentUserService.getRequired(jwt), id, request
        ));
    }
}
