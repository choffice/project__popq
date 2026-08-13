package com.example.project_popq.support.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.support.domain.SupportInquiryStatus;
import com.example.project_popq.support.dto.ChangeSupportInquiryStatusRequest;
import com.example.project_popq.support.dto.SendSupportMessageRequest;
import com.example.project_popq.support.dto.SupportInquiryDetailResponse;
import com.example.project_popq.support.dto.SupportInquirySummaryResponse;
import com.example.project_popq.support.service.AdminSupportInquiryService;
import jakarta.validation.Valid;
import java.util.List;
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
@RequestMapping("/api/v1/admin/support")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminSupportController {

  private final CurrentUserService currentUserService;
  private final AdminSupportInquiryService
      adminSupportInquiryService;

  @GetMapping("/inquiries")
  public ApiResponse<
      List<SupportInquirySummaryResponse>
      > inquiries(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false)
      SupportInquiryStatus status
  ) {
    return ApiResponse.success(
        adminSupportInquiryService.getInquiries(
            currentUserService.getRequired(jwt),
            status
        )
    );
  }

  @GetMapping("/inquiries/{supportInquiryId}")
  public ApiResponse<SupportInquiryDetailResponse>
  inquiry(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long supportInquiryId
  ) {
    return ApiResponse.success(
        adminSupportInquiryService.getInquiry(
            currentUserService.getRequired(jwt),
            supportInquiryId
        )
    );
  }

  @PostMapping(
      "/inquiries/{supportInquiryId}/messages"
  )
  public ApiResponse<SupportInquiryDetailResponse>
  sendAnswer(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long supportInquiryId,
      @Valid
      @RequestBody
      SendSupportMessageRequest request
  ) {
    return ApiResponse.success(
        adminSupportInquiryService.sendAnswer(
            currentUserService.getRequired(jwt),
            supportInquiryId,
            request
        )
    );
  }

  @PatchMapping(
      "/inquiries/{supportInquiryId}/status"
  )
  public ApiResponse<SupportInquirySummaryResponse>
  changeStatus(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long supportInquiryId,
      @Valid
      @RequestBody
      ChangeSupportInquiryStatusRequest request
  ) {
    return ApiResponse.success(
        adminSupportInquiryService.changeStatus(
            currentUserService.getRequired(jwt),
            supportInquiryId,
            request
        )
    );
  }

  @GetMapping("/unread-count")
  public ApiResponse<Long> unreadMessageCount(
      @AuthenticationPrincipal Jwt jwt
  ) {
    return ApiResponse.success(
        adminSupportInquiryService
            .getUnreadMessageCount(
                currentUserService.getRequired(jwt)
            )
    );
  }
}