package com.example.project_popq.store.controller;

import com.example.project_popq.common.api.ApiResponse;
import com.example.project_popq.store.dto.StoreImageUploadResponse;
import com.example.project_popq.store.service.StoreImageStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/v1/seller/store-images")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('SELLER', 'ADMIN')")
public class SellerStoreImageController {

  private final StoreImageStorageService
      storeImageStorageService;

  @PostMapping(
      consumes =
          MediaType.MULTIPART_FORM_DATA_VALUE
  )
  public ResponseEntity<
      ApiResponse<StoreImageUploadResponse>
      > upload(
      @RequestPart("file")
      MultipartFile file
  ) {
    String publicPath =
        storeImageStorageService.store(file);

    String imageUrl =
        ServletUriComponentsBuilder
            .fromCurrentContextPath()
            .path(publicPath)
            .toUriString();

    StoreImageUploadResponse response =
        new StoreImageUploadResponse(
            imageUrl
        );

    return ResponseEntity
        .status(HttpStatus.CREATED)
        .body(
            ApiResponse.success(response)
        );
  }
}