package com.example.project_popq.qr;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class QrApiIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void sellerCatalogIsAvailableThroughGuestQrSession() throws Exception {
        String accessToken = loginSeller();
        Long storeId = createStore(accessToken);
        openStore(accessToken, storeId);
        Long categoryId = createCategory(accessToken, storeId);
        Long productId = createProduct(accessToken, storeId, categoryId);
        QrIssue qr = issueQr(accessToken, storeId);

        mockMvc.perform(get(
                        "/api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}",
                        storeId,
                        qr.qrCodeId()
                )
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.qrCodeId").value(qr.qrCodeId()))
                .andExpect(jsonPath("$.data.publicUrl")
                        .value("https://order.popq.test/q/" + qr.token()));

        MvcResult opened = mockMvc.perform(
                        post("/api/v1/qr/{token}/sessions", qr.token())
                )
                .andExpect(status().isOk())
                .andExpect(cookie().httpOnly("POPQ_GUEST_SESSION", true))
                .andExpect(cookie().secure("POPQ_GUEST_SESSION", false))
                .andExpect(jsonPath("$.data.storeId").value(storeId))
                .andReturn();
        Cookie guestCookie = opened.getResponse()
                .getCookie("POPQ_GUEST_SESSION");

        mockMvc.perform(
                        post("/api/v1/qr/{token}/sessions", qr.token())
                                .cookie(guestCookie)
                )
                .andExpect(status().isOk())
                .andExpect(cookie().value(
                        "POPQ_GUEST_SESSION",
                        guestCookie.getValue()
                ));

        mockMvc.perform(get("/api/v1/qr/products").cookie(guestCookie))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].productId").value(productId))
                .andExpect(jsonPath("$.data[0].name").value("QR 아메리카노"))
                .andExpect(jsonPath("$.data[0].basePrice").value(5000));

        mockMvc.perform(
                        get("/api/v1/qr/products/{productId}", productId)
                                .cookie(guestCookie)
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.product.productId").value(productId));

        mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/revoke",
                        storeId,
                        qr.qrCodeId()
                ).header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk());
        mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/archive",
                        storeId,
                        qr.qrCodeId()
                ).header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archived").value(true));
        mockMvc.perform(get(
                        "/api/v1/seller/stores/{storeId}/qr-codes",
                        storeId
                ).header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data").isEmpty());
        mockMvc.perform(get(
                        "/api/v1/seller/stores/{storeId}/qr-codes?includeArchived=true",
                        storeId
                ).header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].archived").value(true));
        mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/qr-codes/{qrCodeId}/restore",
                        storeId,
                        qr.qrCodeId()
                ).header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.archived").value(false));
    }

    private String loginSeller() throws Exception {
        String response = mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "qr-api-seller@popq.test",
                                  "name": "QR API 판매자",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.accessToken");
    }

    private Long createStore(String token) throws Exception {
        String response = mockMvc.perform(post("/api/v1/seller/stores")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "storeType": "LOCAL_STORE",
                                  "name": "QR API 스토어"
                                }
                                """))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return ((Number) JsonPath.read(response, "$.data.storeId")).longValue();
    }

    private void openStore(String token, Long storeId) throws Exception {
        mockMvc.perform(patch(
                        "/api/v1/seller/stores/{storeId}/business-status",
                        storeId
                )
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"businessStatus": "OPEN"}
                                """))
                .andExpect(status().isOk());
    }

    private Long createCategory(String token, Long storeId) throws Exception {
        String response = mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/categories",
                        storeId
                )
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "커피", "displayOrder": 0}
                                """))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return ((Number) JsonPath.read(response, "$.data.categoryId")).longValue();
    }

    private Long createProduct(
            String token,
            Long storeId,
            Long categoryId
    ) throws Exception {
        String response = mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/products",
                        storeId
                )
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "categoryId": %d,
                                  "name": "QR 아메리카노",
                                  "basePrice": 5000
                                }
                                """.formatted(categoryId)))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return ((Number) JsonPath.read(
                response,
                "$.data.product.productId"
        )).longValue();
    }

    private QrIssue issueQr(String token, Long storeId) throws Exception {
        String response = mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/qr-codes",
                        storeId
                )
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return new QrIssue(
                ((Number) JsonPath.read(
                        response,
                        "$.data.qrCodeId"
                )).longValue(),
                JsonPath.read(response, "$.data.token")
        );
    }

    private record QrIssue(Long qrCodeId, String token) {
    }
}
