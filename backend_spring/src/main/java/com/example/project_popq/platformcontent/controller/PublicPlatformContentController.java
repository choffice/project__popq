package com.example.project_popq.platformcontent.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.dto.FaqResponse;
import com.example.project_popq.platformcontent.dto.PlatformAnnouncementResponse;
import com.example.project_popq.platformcontent.service.PlatformContentService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/public/content")
@RequiredArgsConstructor
public class PublicPlatformContentController {

    private final PlatformContentService service;

    @GetMapping("/announcements")
    public ApiResponse<List<PlatformAnnouncementResponse>> announcements(
            @RequestParam AppAudience audience
    ) {
        return ApiResponse.success(service.publishedAnnouncements(audience));
    }

    @GetMapping("/announcements/{id}")
    public ApiResponse<PlatformAnnouncementResponse> announcement(
            @PathVariable Long id,
            @RequestParam AppAudience audience
    ) {
        return ApiResponse.success(service.publishedAnnouncement(audience, id));
    }

    @GetMapping("/faqs")
    public ApiResponse<List<FaqResponse>> faqs(@RequestParam AppAudience audience) {
        return ApiResponse.success(service.publishedFaqs(audience));
    }
}
