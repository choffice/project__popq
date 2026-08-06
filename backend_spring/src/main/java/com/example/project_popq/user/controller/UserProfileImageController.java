package com.example.project_popq.user.controller;

import com.example.project_popq.auth.service.CurrentUserService;
import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.user.dto.ProfileImageUploadResponse;
import com.example.project_popq.user.service.UserProfileImageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/v1/users/me")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
public class UserProfileImageController {

    private final CurrentUserService currentUserService;
    private final UserProfileImageService userProfileImageService;

    @PostMapping(
        path = "/profile-image",
        consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ResponseEntity<ApiResponse<ProfileImageUploadResponse>> upload(
        @AuthenticationPrincipal Jwt jwt,
        @RequestPart("file") MultipartFile file
    ) {
        Long userId = currentUserService.getRequired(jwt).getId();
        String publicPath = userProfileImageService.updateProfileImage(userId, file);

        String imageUrl = ServletUriComponentsBuilder
            .fromCurrentContextPath()
            .path(publicPath)
            .toUriString();

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(ApiResponse.success(new ProfileImageUploadResponse(imageUrl)));
    }
}
