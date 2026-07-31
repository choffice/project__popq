package com.example.project_popq.dev;

import com.example.project_popq.product.domain.Product;
import com.example.project_popq.product.domain.ProductCategory;
import com.example.project_popq.product.domain.ProductOptionGroup;
import com.example.project_popq.product.repository.ProductCategoryRepository;
import com.example.project_popq.product.repository.ProductRepository;
import com.example.project_popq.seller.domain.SellerProfile;
import com.example.project_popq.seller.domain.SellerVerificationStatus;
import com.example.project_popq.seller.repository.SellerProfileRepository;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreMemberStatus;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.math.BigDecimal;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Component
@Profile("dev")
@RequiredArgsConstructor
@ConditionalOnProperty(
    prefix = "popq.seed",
    name = "enabled",
    havingValue = "true"
)
public class DevDataInitializer implements CommandLineRunner {

  private static final String SELLER_EMAIL = "seller@popq.local";
  private static final String CUSTOMER_EMAIL = "customer@popq.local";

  private final UserRepository userRepository;
  private final SellerProfileRepository sellerProfileRepository;
  private final StoreRepository storeRepository;
  private final StoreMemberRepository storeMemberRepository;
  private final ProductCategoryRepository productCategoryRepository;
  private final ProductRepository productRepository;

  @Override
  @Transactional
  public void run(String... args) {
    User seller = findOrCreateUser(
        SELLER_EMAIL,
        "POPQ 테스트 판매자",
        PlatformRole.SELLER
    );

    ensureVerifiedSellerProfile(seller);

    findOrCreateUser(
        CUSTOMER_EMAIL,
        "POPQ 테스트 고객",
        PlatformRole.CUSTOMER
    );

    boolean alreadyHasStore = !storeMemberRepository
        .findAllByUserIdAndStatusOrderByIdAsc(
            seller.getId(),
            StoreMemberStatus.ACTIVE
        )
        .isEmpty();

    if (alreadyHasStore) {
      log.info(
          "POPQ 개발용 매장 데이터가 이미 존재하여 생성을 건너뜁니다."
      );
      return;
    }

    Store store = createStore();

    storeMemberRepository.save(
        StoreMember.create(
            store,
            seller,
            StoreRole.OWNER
        )
    );

    ProductCategory coffeeCategory =
        productCategoryRepository.save(
            ProductCategory.create(
                store,
                "커피",
                1
            )
        );

    ProductCategory dessertCategory =
        productCategoryRepository.save(
            ProductCategory.create(
                store,
                "디저트",
                2
            )
        );

    Product americano = createAmericano(
        store,
        coffeeCategory
    );

    Product cafeLatte = createCafeLatte(
        store,
        coffeeCategory
    );

    Product croffle = createCroffle(
        store,
        dessertCategory
    );

    productRepository.saveAll(
        List.of(
            americano,
            cafeLatte,
            croffle
        )
    );

    log.info("POPQ 개발용 더미 데이터 생성 완료");
    log.info("판매자 로그인 이메일: {}", SELLER_EMAIL);
    log.info("고객 로그인 이메일: {}", CUSTOMER_EMAIL);
    log.info("테스트 매장: {}", store.getName());
  }

  private User findOrCreateUser(
      String email,
      String name,
      PlatformRole role
  ) {
    return userRepository.findByEmailIgnoreCase(email)
        .map(user -> {
          if (user.getRole() != role) {
            throw new IllegalStateException(
                email
                    + " 이메일이 다른 역할로 "
                    + "이미 등록되어 있습니다."
            );
          }

          return user;
        })
        .orElseGet(() ->
            userRepository.save(
                User.create(
                    email,
                    name,
                    role
                )
            )
        );
  }

  private void ensureVerifiedSellerProfile(User seller) {
    SellerProfile sellerProfile =
        sellerProfileRepository
            .findByUserId(seller.getId())
            .orElseGet(() ->
                SellerProfile.createPending(seller)
            );

    sellerProfile.changeVerificationStatus(
        SellerVerificationStatus.VERIFIED
    );

    sellerProfileRepository.save(sellerProfile);
  }

  private Store createStore() {
    Store store = Store.create(
        StoreType.LOCAL_STORE,
        "POPQ 테스트 카페",
        "주문과 결제 기능을 확인하기 위한 "
            + "개발용 테스트 매장입니다."
    );

    store.updateDiscoveryProfile(
        "서울특별시 강남구 강남대로 396",
        new BigDecimal("37.4979000"),
        new BigDecimal("127.0276000")
    );

    store.changeBusinessStatus(
        BusinessStatus.OPEN
    );

    return storeRepository.save(store);
  }

  private Product createAmericano(
      Store store,
      ProductCategory category
  ) {
    Product product = Product.create(
        store,
        category,
        "아메리카노",
        "깔끔하고 진한 기본 아메리카노",
        null,
        4_000L
    );

    ProductOptionGroup temperature =
        ProductOptionGroup.create(
            product,
            "온도",
            1,
            1,
            true,
            1
        );

    temperature.addOption(
        "ICE",
        0L,
        1
    );

    temperature.addOption(
        "HOT",
        0L,
        2
    );

    ProductOptionGroup extras =
        ProductOptionGroup.create(
            product,
            "추가 옵션",
            0,
            2,
            false,
            2
        );

    extras.addOption(
        "샷 추가",
        500L,
        1
    );

    extras.addOption(
        "사이즈 업",
        1_000L,
        2
    );

    product.replaceOptionGroups(
        List.of(
            temperature,
            extras
        )
    );

    return product;
  }

  private Product createCafeLatte(
      Store store,
      ProductCategory category
  ) {
    Product product = Product.create(
        store,
        category,
        "카페라떼",
        "부드러운 우유와 에스프레소가 어우러진 라떼",
        null,
        5_000L
    );

    ProductOptionGroup temperature =
        ProductOptionGroup.create(
            product,
            "온도",
            1,
            1,
            true,
            1
        );

    temperature.addOption(
        "ICE",
        0L,
        1
    );

    temperature.addOption(
        "HOT",
        0L,
        2
    );

    ProductOptionGroup milk =
        ProductOptionGroup.create(
            product,
            "우유 변경",
            0,
            1,
            false,
            2
        );

    milk.addOption(
        "오트 밀크",
        700L,
        1
    );

    product.replaceOptionGroups(
        List.of(
            temperature,
            milk
        )
    );

    return product;
  }

  private Product createCroffle(
      Store store,
      ProductCategory category
  ) {
    Product product = Product.create(
        store,
        category,
        "플레인 크로플",
        "겉은 바삭하고 속은 촉촉한 기본 크로플",
        null,
        6_500L
    );

    ProductOptionGroup topping =
        ProductOptionGroup.create(
            product,
            "토핑",
            0,
            1,
            false,
            1
        );

    topping.addOption(
        "바닐라 아이스크림",
        1_500L,
        1
    );

    product.replaceOptionGroups(
        List.of(topping)
    );

    return product;
  }
}