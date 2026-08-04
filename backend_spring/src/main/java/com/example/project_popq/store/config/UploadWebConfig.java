package com.example.project_popq.store.config;

import java.nio.file.Path;
import java.nio.file.Paths;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class UploadWebConfig
    implements WebMvcConfigurer {

  private final String uploadPath;

  public UploadWebConfig(
      @Value("${popq.upload.path}")
      String uploadPath
  ) {
    this.uploadPath = uploadPath;
  }

  @Override
  public void addResourceHandlers(
      ResourceHandlerRegistry registry
  ) {
    Path root = Paths.get(uploadPath)
        .toAbsolutePath()
        .normalize();

    String resourceLocation =
        root.toUri().toString();

    if (!resourceLocation.endsWith("/")) {
      resourceLocation += "/";
    }

    registry
        .addResourceHandler(
            "/uploads/**"
        )
        .addResourceLocations(
            resourceLocation
        );
  }
}