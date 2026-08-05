package com.example.project_popq.auth.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(NaverOAuthProperties.class)
public class NaverOAuthConfig {
}