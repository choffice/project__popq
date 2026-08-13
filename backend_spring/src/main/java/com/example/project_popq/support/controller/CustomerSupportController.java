package com.example.project_popq.support.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.support.dto.CreateSupportInquiryRequest;
import com.example.project_popq.support.dto.SendSupportMessageRequest;
import com.example.project_popq.support.dto.SupportFaqResponse;
import com.example.project_popq.support.dto.SupportInquiryDetailResponse;
import com.example.project_popq.support.dto.SupportInquirySummaryResponse;
import com.example.project_popq.support.service.CustomerSupportInquiryService;
import com.example.project_popq.support.service.SupportFaqService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
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
@RequestMapping("/api/v1/customer/support")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerSupportController {

  private final CurrentUserService currentUserService;
  private final SupportFaqService supportFaqService;
  private final CustomerSupportInquiryService
      customerSupportInquiryService;

  @GetMapping("/faqs/popular")
  public ApiResponse<List<SupportFaqResponse>>
  popularFaqs() {
    return ApiResponse.success(
        supportFaqService.getPopularFaqs()
    );
  }

  @GetMapping("/faqs")
  public ApiResponse<List<SupportFaqResponse>>
  faqs(
      @RequestParam(required = false)
      String keyword
  ) {
    if (keyword == null || keyword.isBlank()) {
      return ApiResponse.success(
          supportFaqService.getAllFaqs()
      );
    }

    return ApiResponse.success(
        supportFaqService.searchFaqs(keyword)
    );
  }

  @PostMapping("/inquiries")
  public ResponseEntity<
      ApiResponse<SupportInquiryDetailResponse>
      > createInquiry(
      @AuthenticationPrincipal Jwt jwt,
      @Valid
      @RequestBody
      CreateSupportInquiryRequest request
  ) {
    SupportInquiryDetailResponse created =
        customerSupportInquiryService.createInquiry(
            currentUserService.getRequired(jwt),
            request
        );

    return ResponseEntity
        .status(HttpStatus.CREATED)
        .body(ApiResponse.success(created));
  }

  @GetMapping("/inquiries")
  public ApiResponse<
      List<SupportInquirySummaryResponse>
      > myInquiries(
      @AuthenticationPrincipal Jwt jwt
  ) {
    return ApiResponse.success(
        customerSupportInquiryService.getMyInquiries(
            currentUserService.getRequired(jwt)
        )
    );
  }

  @GetMapping("/inquiries/{supportInquiryId}")
  public ApiResponse<SupportInquiryDetailResponse>
  myInquiry(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long supportInquiryId
  ) {
    return ApiResponse.success(
        customerSupportInquiryService.getMyInquiry(
            currentUserService.getRequired(jwt),
            supportInquiryId
        )
    );
  }

  @PostMapping(
      "/inquiries/{supportInquiryId}/messages"
  )
  public ApiResponse<SupportInquiryDetailResponse>
  sendMessage(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long supportInquiryId,
      @Valid
      @RequestBody
      SendSupportMessageRequest request
  ) {
    return ApiResponse.success(
        customerSupportInquiryService.sendMessage(
            currentUserService.getRequired(jwt),
            supportInquiryId,
            request
        )
    );
  }
}