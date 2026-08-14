package com.example.project_popq.support.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.support.dto.SupportFaqResponse;
import com.example.project_popq.support.service.SupportFaqService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/customer/support")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerSupportController {

  private final SupportFaqService supportFaqService;

  @GetMapping("/faqs/popular")
  public ApiResponse<List<SupportFaqResponse>> popularFaqs() {
    return ApiResponse.success(
        supportFaqService.getPopularFaqs()
    );
  }

  @GetMapping("/faqs")
  public ApiResponse<List<SupportFaqResponse>> faqs(
      @RequestParam(required = false) String keyword
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
}