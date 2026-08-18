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
import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.Faq;
import com.example.project_popq.platformcontent.repository.FaqRepository;

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
  private final FaqRepository faqRepository;
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

    User administrator = userRepository
        .findByEmailIgnoreCase(normalizedEmail)
        .orElse(null);

    if (administrator != null) {
      if (!administrator.hasRole(PlatformRole.ADMIN)) {
        throw new IllegalStateException(
            "관리자 이메일이 다른 역할의 계정으로 이미 등록되어 있습니다: "
                + normalizedEmail
        );
      }

      log.info(
          "기존 관리자 계정을 사용합니다: {}",
          normalizedEmail
      );
    } else {
      administrator = User.createWithPassword(
          normalizedEmail,
          name.trim(),
          null,
          PlatformRole.ADMIN,
          passwordEncoder.encode(password)
      );

      administrator = userRepository.save(administrator);

      log.info(
          "개발용 관리자 계정을 생성했습니다: {}",
          normalizedEmail
      );
    }

    seedDefaultFaqs(administrator);
  }

  private void seedDefaultFaqs(User administrator) {
    createDefaultFaq(
        administrator,
        AppAudience.CUSTOMER_APP,
        "주문",
        "주문을 취소하고 싶어요.",
        "주문 상태에 따라 주문 상세 화면에서 취소할 수 있습니다.",
        1
    );

    createDefaultFaq(
        administrator,
        AppAudience.CUSTOMER_APP,
        "결제",
        "결제 수단을 변경할 수 있나요?",
        "결제가 완료된 주문의 결제 수단은 변경할 수 없습니다.",
        2
    );

    createDefaultFaq(
        administrator,
        AppAudience.CUSTOMER_APP,
        "환불",
        "환불은 언제 처리되나요?",
        "환불 완료 시점은 결제 수단과 카드사 정책에 따라 달라질 수 있습니다.",
        3
    );

    createDefaultFaq(
        administrator,
        AppAudience.CUSTOMER_APP,
        "매장",
        "매장 이용 중 문제가 생겼어요.",
        "주문 관련 문제는 주문 상세의 문의하기 또는 고객센터를 이용해 주세요.",
        4
    );

    createDefaultFaq(
        administrator,
        AppAudience.CUSTOMER_APP,
        "쿠폰",
        "쿠폰이 적용되지 않아요.",
        "쿠폰의 사용 기간과 최소 주문 금액, 적용 가능한 매장을 확인해 주세요.",
        5
    );

    createDefaultFaq(
        administrator,
        AppAudience.CUSTOMER_APP,
        "계정",
        "회원 정보를 변경하고 싶어요.",
        "마이페이지의 내 정보 관리에서 변경할 수 있습니다.",
        6
    );
    createDefaultFaq(
        administrator,
        AppAudience.SELLER_APP,
        "매장",
        "매장 정보는 어디에서 수정하나요?",
        "판매자 앱의 매장 관리 화면에서 매장 정보를 수정할 수 있습니다.",
        1
    );

    createDefaultFaq(
        administrator,
        AppAudience.SELLER_APP,
        "상품",
        "상품은 어떻게 등록하나요?",
        "상품 관리 화면에서 상품 추가 버튼을 눌러 등록할 수 있습니다.",
        2
    );

    createDefaultFaq(
        administrator,
        AppAudience.SELLER_APP,
        "주문",
        "새 주문은 어디에서 확인하나요?",
        "주문 관리 화면에서 접수된 주문과 진행 상태를 확인할 수 있습니다.",
        3
    );

    createDefaultFaq(
        administrator,
        AppAudience.SELLER_APP,
        "주문",
        "주문을 거절할 수 있나요?",
        "접수 전 주문은 주문 상세 화면에서 거절할 수 있습니다.",
        4
    );

    createDefaultFaq(
        administrator,
        AppAudience.SELLER_APP,
        "QR",
        "매장 QR은 어디에서 확인하나요?",
        "QR 관리 화면에서 매장과 테이블별 QR을 확인할 수 있습니다.",
        5
    );

    createDefaultFaq(
        administrator,
        AppAudience.SELLER_APP,
        "정산",
        "매출 내역은 어디에서 확인하나요?",
        "매출 관리 화면에서 기간별 주문과 매출 내역을 확인할 수 있습니다.",
        6
    );
  }



  private void createDefaultFaq(
      User administrator,
      AppAudience audience,
      String category,
      String question,
      String answer,
      int displayOrder
  ) {
    if (faqRepository.existsByAudienceAndQuestion(
        audience,
        question
    )) {
      return;
    }

    faqRepository.save(
        Faq.create(
            administrator,
            audience,
            category,
            question,
            answer,
            displayOrder
        )
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