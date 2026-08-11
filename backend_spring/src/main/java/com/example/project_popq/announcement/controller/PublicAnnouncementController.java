package com.example.project_popq.announcement.controller;

import com.example.project_popq.announcement.dto.AnnouncementResponse;
import com.example.project_popq.announcement.service.PublicAnnouncementQueryService;
import com.example.project_popq.common.api.ApiResponse;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/public/stores/{storeId}/announcements")
@RequiredArgsConstructor
public class PublicAnnouncementController {

    private final PublicAnnouncementQueryService publicAnnouncementQueryService;

    @GetMapping
    public ApiResponse<List<AnnouncementResponse>> findAll(
            @PathVariable Long storeId
    ) {
        return ApiResponse.success(
                publicAnnouncementQueryService.findAll(storeId)
        );
    }

    @GetMapping("/{announcementId}")
    public ApiResponse<AnnouncementResponse> findOne(
            @PathVariable Long storeId,
            @PathVariable Long announcementId
    ) {
        return ApiResponse.success(
                publicAnnouncementQueryService.findOne(storeId, announcementId)
        );
    }
}
