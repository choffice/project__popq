package com.example.project_popq.notification.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.notification.dto.PushDeviceResponse;
import com.example.project_popq.notification.dto.RegisterPushDeviceRequest;
import com.example.project_popq.notification.service.PushDeviceService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/seller")
@RequiredArgsConstructor
@PreAuthorize("hasRole('SELLER')")
public class SellerPushDeviceController {

  private final CurrentUserService currentUserService;
  private final PushDeviceService pushDeviceService;

  @PostMapping("/devices")
  public ApiResponse<PushDeviceResponse> registerDevice(
      @AuthenticationPrincipal Jwt jwt,
      @Valid @RequestBody RegisterPushDeviceRequest request
  ) {
    return ApiResponse.success(
        pushDeviceService.register(
            currentUserService.getRequired(jwt),
            request
        )
    );
  }

  @GetMapping("/devices")
  public ApiResponse<List<PushDeviceResponse>> devices(
      @AuthenticationPrincipal Jwt jwt
  ) {
    return ApiResponse.success(
        pushDeviceService.findMine(
            currentUserService.getRequired(jwt)
        )
    );
  }

  @DeleteMapping("/devices/{deviceId}")
  public ApiResponse<PushDeviceResponse> unregisterDevice(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable Long deviceId
  ) {
    return ApiResponse.success(
        pushDeviceService.unregister(
            currentUserService.getRequired(jwt),
            deviceId
        )
    );
  }
}