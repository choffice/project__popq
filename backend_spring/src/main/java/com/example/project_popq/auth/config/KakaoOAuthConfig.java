package com.example.project_popq.auth.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(KakaoOAuthProperties.class)
public class KakaoOAuthConfig {
}