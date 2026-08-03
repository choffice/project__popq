package com.example.project_popq.dev;
import com.example.project_popq.product.domain.CatalogStatus;
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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;
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

  /*
   * 기존 판매자 앱과 메뉴 테스트에 사용하는 계정입니다.
   * 이 판매자에게는 기존과 동일하게 테스트 카페 하나만 연결합니다.
   */
  private static final String SELLER_EMAIL =
      "seller@popq.local";

  /*
   * 카카오맵과 탐색 탭 테스트 전용 판매자입니다.
   * 지도용 매장 14개는 이 판매자에게 연결합니다.
   */
  private static final String MAP_SELLER_EMAIL =
      "map-seed@popq.local";

  private static final String CUSTOMER_EMAIL =
      "customer@popq.local";

  private static final String PRIMARY_STORE_NAME =
      "POPQ 테스트 카페";

  /*
   * 기존 테스트 카페입니다.
   *
   * 매장 이름과 메뉴 구조는 유지하고,
   * 위치만 서울 강남에서 부산 해운대역 인근으로 변경합니다.
   */
  private static final StoreSeed PRIMARY_STORE_SEED =
      new StoreSeed(
          StoreType.LOCAL_STORE,
          PRIMARY_STORE_NAME,
          "주문과 결제 기능을 확인하기 위한 "
              + "개발용 테스트 매장입니다.",
          "부산광역시 해운대구 우동 해운대역 인근",
          "35.1636700",
          "129.1588900"
      );

  /*
   * 지도 확인용 매장입니다.
   *
   * 실제 부산 지역의 지하철역과 주요 지점을 기준으로
   * 좌표를 배치했으며, 매장 이름은 모두 가상입니다.
   */
  private static final List<StoreSeed> MAP_STORE_SEEDS =
      List.of(
          /*
           * 해운대구
           */
          new StoreSeed(
              StoreType.EVENT_COMMERCE,
              "POPQ 센텀 크리에이터 마켓",
              "센텀 지역의 팝업스토어와 "
                  + "창작 브랜드를 확인하기 위한 행사 매장입니다.",
              "부산광역시 해운대구 우동 센텀시티역 인근",
              "35.1689500",
              "129.1307000"
          ),
          new StoreSeed(
              StoreType.LOCAL_STORE,
              "POPQ 송정 브런치 스토어",
              "송정 지역 로컬 매장 탐색을 위한 "
                  + "개발용 브런치 매장입니다.",
              "부산광역시 해운대구 송정동 송정역 인근",
              "35.1809000",
              "129.2000000"
          ),

          /*
           * 동래구
           */
          new StoreSeed(
              StoreType.LOCAL_STORE,
              "POPQ 동래 온천 로스터리",
              "동래 지역 로컬 카페 탐색을 위한 "
                  + "개발용 테스트 매장입니다.",
              "부산광역시 동래구 온천동 동래역 인근",
              "35.2056000",
              "129.0785000"
          ),
          new StoreSeed(
              StoreType.EVENT_COMMERCE,
              "POPQ 명륜 주말 플리마켓",
              "명륜동 주말 행사를 표현하기 위한 "
                  + "개발용 플리마켓입니다.",
              "부산광역시 동래구 명륜동 명륜역 인근",
              "35.2125000",
              "129.0800000"
          ),
          new StoreSeed(
              StoreType.EVENT_COMMERCE,
              "POPQ 사직 푸드 페스타",
              "사직 지역의 기간 한정 푸드 행사를 위한 "
                  + "개발용 이벤트 매장입니다.",
              "부산광역시 동래구 사직동 사직역 인근",
              "35.1987000",
              "129.0601000"
          ),

          /*
           * 남구
           */
          new StoreSeed(
              StoreType.LOCAL_STORE,
              "POPQ 대연 캠퍼스 카페",
              "대연동 대학가의 로컬 매장을 표현하기 위한 "
                  + "개발용 카페입니다.",
              "부산광역시 남구 대연동 대연역 인근",
              "35.1351000",
              "129.0920000"
          ),
          new StoreSeed(
              StoreType.EVENT_COMMERCE,
              "POPQ 경성대 청년마켓",
              "청년 판매자와 소규모 브랜드 행사를 위한 "
                  + "개발용 이벤트 매장입니다.",
              "부산광역시 남구 대연동 "
                  + "경성대·부경대역 인근",
              "35.1376000",
              "129.1007000"
          ),
          new StoreSeed(
              StoreType.LOCAL_STORE,
              "POPQ 용호 바다 베이커리",
              "용호동 해안 지역 로컬 상점을 표현하기 위한 "
                  + "개발용 베이커리입니다.",
              "부산광역시 남구 용호동 "
                  + "오륙도 스카이워크 인근",
              "35.1023000",
              "129.1229000"
          ),

          /*
           * 수영구
           */
          new StoreSeed(
              StoreType.LOCAL_STORE,
              "POPQ 광안 로컬 디저트",
              "광안동 로컬 디저트 매장 탐색을 위한 "
                  + "개발용 테스트 매장입니다.",
              "부산광역시 수영구 광안동 광안역 인근",
              "35.1579000",
              "129.1132000"
          ),
          new StoreSeed(
              StoreType.EVENT_COMMERCE,
              "POPQ 민락 야간마켓",
              "민락 지역의 야간 행사와 푸드마켓을 위한 "
                  + "개발용 이벤트 매장입니다.",
              "부산광역시 수영구 민락동 민락역 인근",
              "35.1672000",
              "129.1208000"
          ),
          new StoreSeed(
              StoreType.EVENT_COMMERCE,
              "POPQ 수영강 팝업스토어",
              "수영강 인근 기간 한정 팝업 행사를 위한 "
                  + "개발용 이벤트 매장입니다.",
              "부산광역시 수영구 수영동 수영역 인근",
              "35.1670000",
              "129.1147000"
          ),

          /*
           * 금정구
           */
          new StoreSeed(
              StoreType.LOCAL_STORE,
              "POPQ 부산대 북카페",
              "부산대학교 인근 로컬 매장을 표현하기 위한 "
                  + "개발용 북카페입니다.",
              "부산광역시 금정구 장전동 부산대역 인근",
              "35.2299000",
              "129.0890000"
          ),
          new StoreSeed(
              StoreType.LOCAL_STORE,
              "POPQ 구서 생활마켓",
              "구서동 생활권의 로컬 상점을 표현하기 위한 "
                  + "개발용 테스트 매장입니다.",
              "부산광역시 금정구 구서동 구서역 인근",
              "35.2473000",
              "129.0913000"
          ),
          new StoreSeed(
              StoreType.EVENT_COMMERCE,
              "POPQ 범어사 산책마켓",
              "금정산과 범어사 인근의 주말 행사를 표현하기 위한 "
                  + "개발용 이벤트 매장입니다.",
              "부산광역시 금정구 남산동 범어사역 인근",
              "35.2732000",
              "129.0923000"
          )
      );

  private final UserRepository userRepository;

  private final SellerProfileRepository
      sellerProfileRepository;

  private final StoreRepository storeRepository;

  private final StoreMemberRepository
      storeMemberRepository;

  private final ProductCategoryRepository
      productCategoryRepository;

  private final ProductRepository productRepository;

  @Override
  @Transactional
  public void run(String... args) {
    /*
     * 기존 메뉴와 주문 테스트용 판매자입니다.
     */
    User seller = findOrCreateUser(
        SELLER_EMAIL,
        "POPQ 테스트 판매자",
        PlatformRole.SELLER
    );

    ensureVerifiedSellerProfile(seller);

    /*
     * 카카오맵 매장 핀 테스트 전용 판매자입니다.
     */
    User mapSeller = findOrCreateUser(
        MAP_SELLER_EMAIL,
        "POPQ 지도 테스트 판매자",
        PlatformRole.SELLER
    );

    ensureVerifiedSellerProfile(mapSeller);

    /*
     * 기존 테스트 고객 계정입니다.
     */
    findOrCreateUser(
        CUSTOMER_EMAIL,
        "POPQ 테스트 고객",
        PlatformRole.CUSTOMER
    );

    /*
     * 기존 테스트 카페를 생성하거나,
     * 이미 있다면 부산 좌표로 갱신합니다.
     */
    SeededStore primaryStoreResult =
        ensureStore(
            seller,
            PRIMARY_STORE_SEED
        );

    /*
     * 테스트 카페가 이번 실행에서 새로 생성됐을 때만
     * 기존 커피·디저트 메뉴를 생성합니다.
     *
     * 이미 존재하는 매장에 메뉴를 다시 넣지 않기 때문에
     * 반복 실행해도 메뉴가 중복되지 않습니다.
     */
    if (primaryStoreResult.created()) {
      createPrimaryStoreMenu(
          primaryStoreResult.store()
      );
    }

    /*
     * 지도 테스트 전용 판매자에게
     * 부산 지역 매장 14개를 생성하거나 갱신합니다.
     */
    SeedSummary mapSeedSummary =
        ensureMapStores(mapSeller);

    log.info("POPQ 개발용 더미 데이터 준비 완료");
    log.info("기존 판매자 로그인 이메일: {}", SELLER_EMAIL);
    log.info(
        "지도 테스트 판매자 이메일: {}",
        MAP_SELLER_EMAIL
    );
    log.info("고객 로그인 이메일: {}", CUSTOMER_EMAIL);
    log.info(
        "기본 테스트 매장: {}",
        primaryStoreResult.store().getName()
    );
    log.info(
        "지도용 매장 생성 수: {}",
        mapSeedSummary.createdCount()
    );
    log.info(
        "지도용 매장 갱신 수: {}",
        mapSeedSummary.updatedCount()
    );
  }

  /*
   * 특정 판매자에게 seed 매장이 있는지 확인합니다.
   *
   * 동일한 이름의 매장이 이미 있으면 새로 만들지 않고
   * 주소·좌표·설명·영업 상태만 갱신합니다.
   */
  private SeededStore ensureStore(
      User owner,
      StoreSeed seed
  ) {
    Map<String, Store> existingStores =
        findActiveStoresByName(owner);

    Store existingStore =
        existingStores.get(seed.name());

    if (existingStore != null) {
      applyStoreSeed(
          existingStore,
          seed
      );

      Store updatedStore =
          storeRepository.save(existingStore);

      return new SeededStore(
          updatedStore,
          false
      );
    }

    Store createdStore =
        createStoreFromSeed(seed);

    storeMemberRepository.save(
        StoreMember.create(
            createdStore,
            owner,
            StoreRole.OWNER
        )
    );

    return new SeededStore(
        createdStore,
        true
    );
  }

  /*
   * 지도 전용 판매자의 부산 매장 14개를
   * 이름 기준으로 생성하거나 갱신합니다.
   */
  private SeedSummary ensureMapStores(
    User mapSeller
) {
  Map<String, Store> existingStores =
      findActiveStoresByName(mapSeller);

  int createdCount = 0;
  int updatedCount = 0;

  for (StoreSeed seed : MAP_STORE_SEEDS) {
    Store store =
        existingStores.get(seed.name());

    if (store == null) {
      store = createStoreFromSeed(seed);

      storeMemberRepository.save(
          StoreMember.create(
              store,
              mapSeller,
              StoreRole.OWNER
          )
      );

      existingStores.put(
          seed.name(),
          store
      );

      createdCount++;
    } else {
      applyStoreSeed(
          store,
          seed
      );

      store = storeRepository.save(store);

      updatedCount++;
    }

    /*
     * 새 매장과 기존 매장 모두 상품을 확인합니다.
     * 따라서 이미 생성해 둔 부산 더미 매장에도
     * 다음 백엔드 실행 시 상품이 추가됩니다.
     */
    ensureSampleProducts(store);
  }

  return new SeedSummary(
      createdCount,
      updatedCount
  );
}

  /*
   * 판매자가 소유한 활성 매장을
   * 매장 이름을 key로 하여 반환합니다.
   *
   * 새로운 Repository 메서드를 추가하지 않고
   * 기존 메서드만 사용합니다.
   */
  private Map<String, Store> findActiveStoresByName(
      User owner
  ) {
    List<StoreMember> storeMembers =
        storeMemberRepository
            .findAllByUserIdAndStatusOrderByIdAsc(
                owner.getId(),
                StoreMemberStatus.ACTIVE
            );

    Map<String, Store> storesByName =
        new LinkedHashMap<>();

    for (StoreMember storeMember : storeMembers) {
      Store store = storeMember.getStore();

      storesByName.putIfAbsent(
          store.getName(),
          store
      );
    }

    return storesByName;
  }

  /*
   * 새로운 매장을 생성하고,
   * 탐색에 필요한 주소·좌표·OPEN 상태를 적용합니다.
   */
  private Store createStoreFromSeed(
      StoreSeed seed
  ) {
    Store store = Store.create(
        seed.storeType(),
        seed.name(),
        seed.description()
    );

    applyStoreSeed(
        store,
        seed
    );

    return storeRepository.save(store);
  }

  /*
   * 이미 존재하는 seed 매장에도 최신 주소와 좌표를
   * 다시 적용할 수 있도록 분리한 메서드입니다.
   */
  private void applyStoreSeed(
      Store store,
      StoreSeed seed
  ) {
    store.updateSellerProfile(
        seed.name(),
        seed.description(),
        seed.address(),
        new BigDecimal(seed.latitude()),
        new BigDecimal(seed.longitude())
    );

    store.changeBusinessStatus(
        BusinessStatus.OPEN
    );
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

  private void ensureVerifiedSellerProfile(
      User seller
  ) {
    SellerProfile sellerProfile =
        sellerProfileRepository
            .findByUserId(seller.getId())
            .orElseGet(() ->
                SellerProfile.createPending(seller)
            );

    sellerProfile.changeVerificationStatus(
        SellerVerificationStatus.VERIFIED
    );

    sellerProfileRepository.save(
        sellerProfile
    );
  }

/*
 * 지도용 더미 매장에 간단한 상품 2개를 보장합니다.
 *
 * 상품 이름을 기준으로 확인하기 때문에
 * 백엔드를 반복 실행해도 같은 상품은 중복 생성되지 않습니다.
 */
private void ensureSampleProducts(
    Store store
) {
  ProductCategory category =
      findOrCreateSeedCategory(store);

  List<Product> existingProducts =
      productRepository
          .findAllByStoreIdAndStatusOrderByIdAsc(
              store.getId(),
              CatalogStatus.ACTIVE
          );

  List<Product> productsToCreate =
      new ArrayList<>();

  for (ProductSeed seed :
      sampleProductsFor(store)) {

    boolean alreadyExists =
        existingProducts.stream()
            .anyMatch(product ->
                product.getName()
                    .equalsIgnoreCase(seed.name())
            );

    if (alreadyExists) {
      continue;
    }

    Product product = Product.create(
        store,
        category,
        seed.name(),
        seed.description(),
        null,
        seed.price()
    );

    productsToCreate.add(product);
  }

  if (productsToCreate.isEmpty()) {
    return;
  }

  productRepository.saveAll(
      productsToCreate
  );

  log.info(
      "지도용 상품 생성 완료: 매장={}, 생성 수={}",
      store.getName(),
      productsToCreate.size()
  );
}

/*
 * 매장 유형에 따라 더미 상품 카테고리를 생성하거나
 * 기존 카테고리를 재사용합니다.
 */
private ProductCategory findOrCreateSeedCategory(
    Store store
) {
  String categoryName =
      store.getStoreType()
          == StoreType.EVENT_COMMERCE
          ? "행사 상품"
          : "추천 메뉴";

  return productCategoryRepository
      .findAllByStoreIdOrderByDisplayOrderAscIdAsc(
          store.getId()
      )
      .stream()
      .filter(category ->
          category.getName()
              .equalsIgnoreCase(categoryName)
      )
      .findFirst()
      .orElseGet(() ->
          productCategoryRepository.save(
              ProductCategory.create(
                  store,
                  categoryName,
                  1
              )
          )
      );
}

/*
 * 매장 이름과 유형에 따라 테스트용 상품을 배정합니다.
 *
 * 실제 상품 정보가 아니라
 * 탐색 → 매장 상세 → 상품 → 장바구니 흐름을
 * 확인하기 위한 개발용 데이터입니다.
 */
private List<ProductSeed> sampleProductsFor(
    Store store
) {
  String storeName = store.getName();

  if (storeName.contains("베이커리")
      || storeName.contains("디저트")) {
    return List.of(
        new ProductSeed(
            "버터 소금빵",
            "겉은 바삭하고 속은 부드러운 "
                + "테스트용 소금빵",
            3_500L
        ),
        new ProductSeed(
            "크림 카페라떼",
            "달콤한 크림을 올린 "
                + "테스트용 카페라떼",
            5_500L
        )
    );
  }

  if (storeName.contains("카페")
      || storeName.contains("로스터리")
      || storeName.contains("북카페")
      || storeName.contains("브런치")) {
    return List.of(
        new ProductSeed(
            "시그니처 아메리카노",
            "매장 대표 원두로 만든 "
                + "테스트용 아메리카노",
            4_500L
        ),
        new ProductSeed(
            "오늘의 디저트",
            "음료와 함께 주문할 수 있는 "
                + "테스트용 디저트",
            6_000L
        )
    );
  }

  if (storeName.contains("생활마켓")) {
    return List.of(
        new ProductSeed(
            "로컬 에코백",
            "지역 마켓 콘셉트의 "
                + "테스트용 에코백",
            9_000L
        ),
        new ProductSeed(
            "수제 비누 세트",
            "개발 테스트를 위한 "
                + "수제 비누 2개 세트",
            7_000L
        )
    );
  }

  if (storeName.contains("푸드")) {
    return List.of(
        new ProductSeed(
            "푸드 교환권",
            "행사장에서 메뉴와 교환하는 "
                + "테스트용 상품",
            8_000L
        ),
        new ProductSeed(
            "음료 교환권",
            "행사장에서 음료와 교환하는 "
                + "테스트용 상품",
            3_500L
        )
    );
  }

  if (store.getStoreType()
      == StoreType.EVENT_COMMERCE) {
    return List.of(
        new ProductSeed(
            "행사 한정 굿즈",
            "행사 기간에만 주문할 수 있는 "
                + "테스트용 굿즈",
            12_000L
        ),
        new ProductSeed(
            "현장 픽업 패키지",
            "현장에서 수령하는 "
                + "테스트용 패키지 상품",
            15_000L
        )
    );
  }

  return List.of(
      new ProductSeed(
          "매장 시그니처 상품",
          "로컬 매장의 대표 상품을 표현한 "
              + "개발용 테스트 상품",
          7_000L
      ),
      new ProductSeed(
          "오늘의 추천 상품",
          "상품 주문 흐름 확인을 위한 "
              + "개발용 추천 상품",
          5_500L
      )
  );
}

  /*
   * 기존 테스트 카페에만 메뉴 데이터를 생성합니다.
   *
   * 지도용 매장에는 메뉴를 넣지 않으므로
   * 기존 판매자 앱 메뉴 테스트 구조를 유지합니다.
   */
  private void createPrimaryStoreMenu(
      Store store
  ) {
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

    Product americano =
        createAmericano(
            store,
            coffeeCategory
        );

    Product cafeLatte =
        createCafeLatte(
            store,
            coffeeCategory
        );

    Product croffle =
        createCroffle(
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

  /*
   * 한 개의 매장 seed 정보를 나타냅니다.
   *
   * 좌표를 String으로 보관한 뒤 BigDecimal로 변환해
   * 기존 Store API 형태를 그대로 사용합니다.
   */
  private record StoreSeed(
      StoreType storeType,
      String name,
      String description,
      String address,
      String latitude,
      String longitude
  ) {
  }

/*
 * 지도용 매장에 생성할 간단한 상품 정보입니다.
 */
private record ProductSeed(
    String name,
    String description,
    long price
) {
}

  /*
   * 매장이 이번 실행에서 새로 생성되었는지를 구분합니다.
   *
   * 새로 생성된 기본 테스트 카페에만
   * 메뉴 데이터를 넣기 위해 사용합니다.
   */
  private record SeededStore(
      Store store,
      boolean created
  ) {
  }

  private record SeedSummary(
      int createdCount,
      int updatedCount
  ) {
  }
}

