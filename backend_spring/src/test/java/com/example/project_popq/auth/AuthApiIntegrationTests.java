package com.example.project_popq.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthApiIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private StoreRepository storeRepository;

    @Autowired
    private StoreMemberRepository storeMemberRepository;

    @Autowired
    private UserRepository userRepository;

    @Test
    void unauthenticatedRequestUsesCommonErrorResponse() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code")
                        .value("AUTHENTICATION_REQUIRED"));
    }

    @Test
    void sellerCanLoginCreateStoreAndListOwnStore() throws Exception {
        String accessToken = login(
                "seller-api@popq.test",
                "판매자 테스트",
                "SELLER"
        );

        mockMvc.perform(post("/api/v1/seller/stores")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "storeType": "LOCAL_STORE",
                                  "name": "POPQ 테스트 스토어",
                                  "description": "통합 테스트 스토어"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.name").value("POPQ 테스트 스토어"))
                .andExpect(jsonPath("$.data.myRole").value("OWNER"))
                .andExpect(jsonPath("$.data.businessStatus").value("PRE_OPEN"));

        mockMvc.perform(get("/api/v1/seller/stores")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data[0].name")
                        .value("POPQ 테스트 스토어"))
                .andExpect(jsonPath("$.data[0].myRole").value("OWNER"));
    }

    @Test
    void customerCannotAccessSellerStoreApi() throws Exception {
        String accessToken = login(
                "customer-api@popq.test",
                "고객 테스트",
                "CUSTOMER"
        );

        mockMvc.perform(get("/api/v1/seller/stores")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("ACCESS_DENIED"));
    }

    @Test
    void ownerCanUpdateStoreDetailAndOtherSellerCannotAccessIt()
            throws Exception {
        String ownerToken = login(
                "store-detail-owner@popq.test",
                "사업장 소유자",
                "SELLER"
        );
        Long storeId = createStore(ownerToken, "수정 전 사업장");

        mockMvc.perform(patch("/api/v1/seller/stores/{storeId}", storeId)
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "수정된 성수 사업장",
                                  "description": "운영정보 수정 완료",
                                  "address": "서울 성동구 연무장길 1",
                                  "latitude": 37.5445000,
                                  "longitude": 127.0560000,
                                  "tags": ["Coffee", "Dessert", "coffee"]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("수정된 성수 사업장"))
                .andExpect(jsonPath("$.data.address")
                        .value("서울 성동구 연무장길 1"))
                .andExpect(jsonPath("$.data.latitude").value(37.5445))
                .andExpect(jsonPath("$.data.longitude").value(127.056))
                .andExpect(jsonPath("$.data.tags.length()").value(2))
                .andExpect(jsonPath("$.data.tags[0]").value("coffee"))
                .andExpect(jsonPath("$.data.tags[1]").value("dessert"))
                .andExpect(jsonPath("$.data.myRole").value("OWNER"));

        mockMvc.perform(get("/api/v1/seller/stores/{storeId}", storeId)
                        .header("Authorization", "Bearer " + ownerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("수정된 성수 사업장"))
                .andExpect(jsonPath("$.data.tags.length()").value(2));

        String otherToken = login(
                "store-detail-other@popq.test",
                "다른 판매자",
                "SELLER"
        );
        mockMvc.perform(get("/api/v1/seller/stores/{storeId}", storeId)
                        .header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code")
                        .value("STORE_ACCESS_DENIED"));
        mockMvc.perform(patch("/api/v1/seller/stores/{storeId}", storeId)
                        .header("Authorization", "Bearer " + otherToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "침범 시도",
                                  "tags": []
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code")
                        .value("STORE_ACCESS_DENIED"));
    }

    @Test
    void ownerCanUpdateCategoryAndProductInsideOwnStore() throws Exception {
        String ownerToken = login(
                "catalog-editor@popq.test",
                "Catalog Editor",
                "SELLER"
        );
        Long storeId = createStore(ownerToken, "Catalog Store");

        String categoryResponse = mockMvc.perform(
                        post("/api/v1/seller/stores/{storeId}/categories", storeId)
                                .header("Authorization", "Bearer " + ownerToken)
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "name": "Coffee",
                                          "displayOrder": 0
                                        }
                                        """)
                )
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        Long categoryId = ((Number) JsonPath.read(
                categoryResponse,
                "$.data.categoryId"
        )).longValue();

        String productResponse = mockMvc.perform(
                        post("/api/v1/seller/stores/{storeId}/products", storeId)
                                .header("Authorization", "Bearer " + ownerToken)
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "categoryId": %d,
                                          "name": "Americano",
                                          "description": "Original",
                                          "imageUrl": null,
                                          "basePrice": 4500
                                        }
                                        """.formatted(categoryId))
                )
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        Long productId = ((Number) JsonPath.read(
                productResponse,
                "$.data.product.productId"
        )).longValue();

        mockMvc.perform(patch(
                        "/api/v1/seller/stores/{storeId}/categories/{categoryId}",
                        storeId,
                        categoryId
                )
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "Signature Coffee",
                                  "displayOrder": 2
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Signature Coffee"))
                .andExpect(jsonPath("$.data.displayOrder").value(2));

        mockMvc.perform(patch(
                        "/api/v1/seller/stores/{storeId}/products/{productId}",
                        storeId,
                        productId
                )
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "categoryId": %d,
                                  "name": "Cream Americano",
                                  "description": "Updated",
                                  "imageUrl": "https://example.test/menu.jpg",
                                  "basePrice": 6000
                                }
                                """.formatted(categoryId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.product.name")
                        .value("Cream Americano"))
                .andExpect(jsonPath("$.data.product.categoryName")
                        .value("Signature Coffee"))
                .andExpect(jsonPath("$.data.product.basePrice").value(6000));

        String otherToken = login(
                "catalog-intruder@popq.test",
                "Catalog Intruder",
                "SELLER"
        );
        mockMvc.perform(patch(
                        "/api/v1/seller/stores/{storeId}/products/{productId}",
                        storeId,
                        productId
                )
                        .header("Authorization", "Bearer " + otherToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "categoryId": %d,
                                  "name": "Intrusion",
                                  "basePrice": 0
                                }
                                """.formatted(categoryId)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code")
                        .value("STORE_ACCESS_DENIED"));
    }

    @Test
    void ownerManagesAnnouncementsWhileStaffCanOnlyRead() throws Exception {
        String ownerToken = login(
                "announcement-owner@popq.test",
                "Announcement Owner",
                "SELLER"
        );
        Long storeId = createStore(ownerToken, "Announcement Store");

        String createResponse = mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/announcements",
                        storeId
                )
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Holiday hours",
                                  "content": "We close at 6 PM."
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.status").value("DRAFT"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        Long announcementId = ((Number) JsonPath.read(
                createResponse,
                "$.data.announcementId"
        )).longValue();

        mockMvc.perform(patch(
                        "/api/v1/seller/stores/{storeId}/announcements/{announcementId}",
                        storeId,
                        announcementId
                )
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "title": "Updated holiday hours",
                                  "content": "We close at 5 PM."
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title")
                        .value("Updated holiday hours"));

        mockMvc.perform(patch(
                        "/api/v1/seller/stores/{storeId}/announcements/{announcementId}/status",
                        storeId,
                        announcementId
                )
                        .header("Authorization", "Bearer " + ownerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "PUBLISHED"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PUBLISHED"))
                .andExpect(jsonPath("$.data.publishedAt").isNotEmpty());

        String staffEmail = "announcement-staff@popq.test";
        String staffToken = login(
                staffEmail,
                "Announcement Staff",
                "SELLER"
        );
        storeMemberRepository.save(
                StoreMember.create(
                        storeRepository.findById(storeId).orElseThrow(),
                        userRepository.findByEmailIgnoreCase(staffEmail)
                                .orElseThrow(),
                        StoreRole.STAFF
                )
        );

        mockMvc.perform(get(
                        "/api/v1/seller/stores/{storeId}/announcements",
                        storeId
                )
                        .header("Authorization", "Bearer " + staffToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].status").value("PUBLISHED"));

        mockMvc.perform(patch(
                        "/api/v1/seller/stores/{storeId}/announcements/{announcementId}/status",
                        storeId,
                        announcementId
                )
                        .header("Authorization", "Bearer " + staffToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "status": "HIDDEN"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code")
                        .value("STORE_ACCESS_DENIED"));

        String otherToken = login(
                "announcement-other@popq.test",
                "Announcement Other",
                "SELLER"
        );
        mockMvc.perform(get(
                        "/api/v1/seller/stores/{storeId}/announcements",
                        storeId
                )
                        .header("Authorization", "Bearer " + otherToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code")
                        .value("STORE_ACCESS_DENIED"));
    }

    @Test
    void sameEmailCannotSwitchBetweenSellerAndCustomerRoles()
            throws Exception {
        String accessToken = login(
                "role-boundary@popq.test",
                "역할 경계 판매자",
                "SELLER"
        );

        mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "ROLE-BOUNDARY@POPQ.TEST",
                                  "name": "역할 변경 시도",
                                  "role": "CUSTOMER"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("DUPLICATE_USER"));

        mockMvc.perform(get("/api/v1/auth/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.email")
                        .value("role-boundary@popq.test"))
                .andExpect(jsonPath("$.data.role").value("SELLER"));
    }

    @Test
    void devLoginRejectsAdminRole() throws Exception {
        mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "admin-api@popq.test",
                                  "name": "관리자 테스트",
                                  "role": "ADMIN"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("INVALID_DEV_ROLE"));
    }

    @Test
    void configuredWebOriginsCanUseCredentialedCors() throws Exception {
        mockMvc.perform(options("/api/v1/qr/stores/1/products")
                        .header("Origin", "http://localhost:5174")
                        .header("Access-Control-Request-Method", "GET")
                        .header(
                                "Access-Control-Request-Headers",
                                "Authorization,Content-Type"
                        ))
                .andExpect(status().isOk())
                .andExpect(header().string(
                        "Access-Control-Allow-Origin",
                        "http://localhost:5174"
                ))
                .andExpect(header().string(
                        "Access-Control-Allow-Credentials",
                        "true"
                ));
    }

    @Test
    void unknownWebOriginIsRejected() throws Exception {
        mockMvc.perform(options("/api/v1/qr/stores/1/products")
                        .header("Origin", "https://malicious.example")
                        .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
    }

    @Test
    void healthEndpointIsPublic() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    private String login(String email, String name, String role) throws Exception {
        String response = mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s",
                                  "name": "%s",
                                  "role": "%s"
                                }
                                """.formatted(email, name, role)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.tokenType").value("Bearer"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(response, "$.data.accessToken");
    }

    private Long createStore(String accessToken, String name) throws Exception {
        String response = mockMvc.perform(post("/api/v1/seller/stores")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "storeType": "LOCAL_STORE",
                                  "name": "%s",
                                  "tags": ["initial"]
                                }
                                """.formatted(name)))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return ((Number) JsonPath.read(response, "$.data.storeId")).longValue();
    }
}
