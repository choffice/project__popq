package com.example.project_popq.dev;

import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Component
@Profile("dev")
@RequiredArgsConstructor
@ConditionalOnProperty(
    prefix = "popq.admin-seed",
    name = "enabled",
    havingValue = "true"
)
public class AdminAccountInitializer implements CommandLineRunner {

  private final UserRepository userRepository;
  private final PasswordEncoder passwordEncoder;

  @Value("${popq.admin-seed.email:}")
  private String email;

  @Value("${popq.admin-seed.password:}")
  private String password;

  @Value("${popq.admin-seed.name:POPQ 관리자}")
  private String name;

  @Override
  @Transactional
  public void run(String... args) {
    validateSettings();

    String normalizedEmail =
        email.trim().toLowerCase();

    User existingUser = userRepository
        .findByEmailIgnoreCase(normalizedEmail)
        .orElse(null);

    if (existingUser != null) {
      if (!existingUser.hasRole(PlatformRole.ADMIN)) {
        throw new IllegalStateException(
            "관리자 이메일이 다른 역할의 계정으로 이미 등록되어 있습니다: "
                + normalizedEmail
        );
      }

      log.info(
          "기존 관리자 계정을 사용합니다: {}",
          normalizedEmail
      );
      return;
    }

    User administrator = User.createWithPassword(
        normalizedEmail,
        name.trim(),
        null,
        PlatformRole.ADMIN,
        passwordEncoder.encode(password)
    );

    userRepository.save(administrator);

    log.info(
        "개발용 관리자 계정을 생성했습니다: {}",
        normalizedEmail
    );
  }

  private void validateSettings() {
    if (email == null || email.isBlank()) {
      throw new IllegalStateException(
          "POPQ_ADMIN_EMAIL 환경변수가 필요합니다."
      );
    }

    if (name == null || name.isBlank()) {
      throw new IllegalStateException(
          "POPQ_ADMIN_NAME 환경변수가 비어 있습니다."
      );
    }

    if (password == null || password.isBlank()) {
      throw new IllegalStateException(
          "POPQ_ADMIN_PASSWORD 환경변수가 필요합니다."
      );
    }

    if (password.length() < 8
        || !password.matches(".*[A-Za-z].*")
        || !password.matches(".*\\d.*")) {
      throw new IllegalStateException(
          "관리자 비밀번호는 영문과 숫자를 포함해 8자 이상이어야 합니다."
      );
    }
  }
}