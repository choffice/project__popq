package com.example.project_popq.user.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ProfileImageStorageService {

  private static final long MAX_FILE_SIZE =
      10L * 1024L * 1024L;

  private static final String PROFILE_IMAGE_DIRECTORY =
      "profile-images";

  private final Path imageDirectory;

  public ProfileImageStorageService(
      @Value("${popq.upload.path}")
      String uploadPath
  ) {
    this.imageDirectory = Paths.get(uploadPath)
        .toAbsolutePath()
        .normalize()
        .resolve(PROFILE_IMAGE_DIRECTORY);
  }

  public String store(
      MultipartFile file
  ) {
    if (file == null || file.isEmpty()) {
      throw new BusinessException(
          ErrorCode.INVALID_UPLOAD_FILE,
          "업로드할 이미지 파일을 선택해 주세요."
      );
    }

    if (file.getSize() > MAX_FILE_SIZE) {
      throw new BusinessException(
          ErrorCode.UPLOAD_FILE_TOO_LARGE,
          "이미지는 최대 10MB까지 업로드할 수 있습니다."
      );
    }

    try {
      byte[] bytes = file.getBytes();

      String extension =
          detectImageExtension(bytes);

      Files.createDirectories(
          imageDirectory
      );

      String storedFileName =
          UUID.randomUUID() + extension;

      Path destination =
          imageDirectory.resolve(
              storedFileName
          );

      Files.write(
          destination,
          bytes,
          StandardOpenOption.CREATE_NEW
      );

      return "/uploads/"
          + PROFILE_IMAGE_DIRECTORY
          + "/"
          + storedFileName;
    } catch (BusinessException exception) {
      throw exception;
    } catch (IOException exception) {
      throw new BusinessException(
          ErrorCode.FILE_STORAGE_FAILED
      );
    }
  }

  private String detectImageExtension(
      byte[] bytes
  ) {
    if (isJpeg(bytes)) {
      return ".jpg";
    }

    if (isPng(bytes)) {
      return ".png";
    }

    if (isWebp(bytes)) {
      return ".webp";
    }

    throw new BusinessException(
        ErrorCode.INVALID_UPLOAD_FILE,
        "JPG, PNG 또는 WEBP 이미지 파일만 업로드할 수 있습니다."
    );
  }

  private boolean isJpeg(
      byte[] bytes
  ) {
    return bytes.length >= 3
        && bytes[0] == (byte) 0xFF
        && bytes[1] == (byte) 0xD8
        && bytes[2] == (byte) 0xFF;
  }

  private boolean isPng(
      byte[] bytes
  ) {
    return bytes.length >= 8
        && bytes[0] == (byte) 0x89
        && bytes[1] == (byte) 0x50
        && bytes[2] == (byte) 0x4E
        && bytes[3] == (byte) 0x47
        && bytes[4] == (byte) 0x0D
        && bytes[5] == (byte) 0x0A
        && bytes[6] == (byte) 0x1A
        && bytes[7] == (byte) 0x0A;
  }

  private boolean isWebp(
      byte[] bytes
  ) {
    return bytes.length >= 12
        && bytes[0] == (byte) 'R'
        && bytes[1] == (byte) 'I'
        && bytes[2] == (byte) 'F'
        && bytes[3] == (byte) 'F'
        && bytes[8] == (byte) 'W'
        && bytes[9] == (byte) 'E'
        && bytes[10] == (byte) 'B'
        && bytes[11] == (byte) 'P';
  }
}
