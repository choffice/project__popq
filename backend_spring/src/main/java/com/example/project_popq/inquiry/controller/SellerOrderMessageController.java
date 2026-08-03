package com.example.project_popq.inquiry.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.inquiry.dto.OrderMessageResponse;
import com.example.project_popq.inquiry.dto.SellerConversationDetailResponse;
import com.example.project_popq.inquiry.dto.SellerConversationSummaryResponse;
import com.example.project_popq.inquiry.dto.SendOrderMessageRequest;
import com.example.project_popq.inquiry.service.OrderMessageService;
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
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller/stores/{storeId}")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerOrderMessageController {

  private final CurrentUserService currentUserService;
  private final OrderMessageService orderMessageService;

  @GetMapping("/conversations")
  public ApiResponse<List<SellerConversationSummaryResponse>>
  findConversations(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long storeId
  ) {
    return ApiResponse.success(
        orderMessageService.findSellerConversations(
            currentUserService.getRequired(jwt),
            storeId
        )
    );
  }

  @GetMapping("/conversations/unread-count")
  public ApiResponse<Long> countUnreadMessages(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long storeId
  ) {
    return ApiResponse.success(
        orderMessageService.countSellerUnreadMessages(
            currentUserService.getRequired(jwt),
            storeId
        )
    );
  }

  @GetMapping("/orders/{orderPublicId}/messages")
  public ApiResponse<SellerConversationDetailResponse>
  findConversation(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long storeId,
      @PathVariable String orderPublicId
  ) {
    return ApiResponse.success(
        orderMessageService.findSellerConversation(
            currentUserService.getRequired(jwt),
            storeId,
            orderPublicId
        )
    );
  }

  @PostMapping("/orders/{orderPublicId}/messages")
  public ResponseEntity<ApiResponse<OrderMessageResponse>>
  sendMessage(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long storeId,
      @PathVariable String orderPublicId,
      @Valid @RequestBody SendOrderMessageRequest request
  ) {
    OrderMessageResponse created =
        orderMessageService.sendSellerMessage(
            currentUserService.getRequired(jwt),
            storeId,
            orderPublicId,
            request
        );

    return ResponseEntity
        .status(HttpStatus.CREATED)
        .body(ApiResponse.success(created));
  }
}