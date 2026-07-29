package com.example.project_popq.auth.controller;

import com.example.project_popq.auth.dto.DevLoginRequest;
import com.example.project_popq.auth.dto.DevLoginResponse;
import com.example.project_popq.auth.service.DevAuthService;
import com.example.project_popq.common.api.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/dev/auth")
@RequiredArgsConstructor
@ConditionalOnProperty(
        name = "popq.auth.dev-login-enabled",
        havingValue = "true"
)
public class DevAuthController {

    private final DevAuthService devAuthService;

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<DevLoginResponse>> login(
            @Valid @RequestBody DevLoginRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(devAuthService.login(request)));
    }
}

