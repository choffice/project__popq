package com.example.project_popq.inquiry.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.inquiry.dto.CustomerOrderUnreadMessageResponse;
import com.example.project_popq.inquiry.dto.OrderMessageResponse;
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
@RequestMapping("/api/v1/customer/orders")
@RequiredArgsConstructor
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerOrderMessageController {

  private final CurrentUserService currentUserService;
  private final OrderMessageService orderMessageService;

  @GetMapping("/messages/unread-counts")
  public ApiResponse<List<CustomerOrderUnreadMessageResponse>>
  findUnreadMessageCounts(
      @AuthenticationPrincipal Jwt jwt
  ) {
    return ApiResponse.success(
        orderMessageService.findCustomerUnreadMessageCounts(
            currentUserService.getRequired(jwt)
        )
    );
  }

  @GetMapping("/{orderPublicId}/messages")
  public ApiResponse<List<OrderMessageResponse>> findMessages(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable String orderPublicId
  ) {
    return ApiResponse.success(
        orderMessageService.findCustomerMessages(
            currentUserService.getRequired(jwt),
            orderPublicId
        )
    );
  }

  @PostMapping("/{orderPublicId}/messages")
  public ResponseEntity<ApiResponse<OrderMessageResponse>> sendMessage(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable String orderPublicId,
      @Valid @RequestBody SendOrderMessageRequest request
  ) {
    OrderMessageResponse created =
        orderMessageService.sendCustomerMessage(
            currentUserService.getRequired(jwt),
            orderPublicId,
            request
        );

    return ResponseEntity
        .status(HttpStatus.CREATED)
        .body(ApiResponse.success(created));
  }
}