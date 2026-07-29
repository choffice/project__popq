package com.example.project_popq.order;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import jakarta.servlet.http.Cookie;
import java.util.UUID;
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
class OrderApiIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void guestPaymentAndSellerLifecycleWorkThroughHttpApi() throws Exception {
        String sellerToken = loginSeller();
        Long storeId = createStore(sellerToken);
        openStore(sellerToken, storeId);
        Long categoryId = createCategory(sellerToken, storeId);
        Long productId = createProduct(sellerToken, storeId, categoryId);
        Cookie guestCookie = openGuestSession(
                issueQr(sellerToken, storeId)
        );

        String orderResponse = mockMvc.perform(post("/api/v1/qr/orders")
                        .cookie(guestCookie)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idempotencyKey": "api-order-key-01",
                                  "orderType": "TAKEOUT",
                                  "items": [{
                                    "productId": %d,
                                    "quantity": 2,
                                    "optionIds": []
                                  }]
                                }
                                """.formatted(productId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.totalAmount").value(10_000))
                .andExpect(jsonPath("$.data.status").value("CREATED"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String orderPublicId = JsonPath.read(
                orderResponse,
                "$.data.orderPublicId"
        );

        mockMvc.perform(post(
                        "/api/v1/qr/orders/{orderPublicId}/payments",
                        orderPublicId
                )
                        .cookie(guestCookie)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idempotencyKey": "api-payment-key-01",
                                  "simulateFailure": false
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PAID"))
                .andExpect(jsonPath("$.data.orderStatus").value("PLACED"));

        mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/orders/{orderId}/accept",
                        storeId,
                        orderPublicId
                )
                        .header("Authorization", "Bearer " + sellerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"));

        mockMvc.perform(get(
                        "/api/v1/seller/stores/{storeId}/orders/{orderId}",
                        storeId,
                        orderPublicId
                )
                        .header("Authorization", "Bearer " + sellerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"))
                .andExpect(jsonPath("$.data.version").value(2))
                .andExpect(jsonPath("$.data.statusHistory.length()").value(3));

        mockMvc.perform(get(
                        "/api/v1/qr/orders/{orderId}/sync",
                        orderPublicId
                )
                        .cookie(guestCookie)
                        .param("knownVersion", "0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.refreshRequired").value(true))
                .andExpect(jsonPath("$.data.serverVersion").value(2))
                .andExpect(jsonPath("$.data.order.status").value("ACCEPTED"));

        mockMvc.perform(get(
                        "/api/v1/qr/orders/{orderId}/sync",
                        orderPublicId
                )
                        .cookie(guestCookie)
                        .param("knownVersion", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.refreshRequired").value(false))
                .andExpect(jsonPath("$.data.serverVersion").value(2))
                .andExpect(jsonPath("$.data.order").doesNotExist());
    }

    private String loginSeller() throws Exception {
        String response = mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s",
                                  "name": "주문 API 판매자",
                                  "role": "SELLER"
                                }
                                """.formatted(
                                "order-api-" + UUID.randomUUID() + "@popq.test"
                        )))
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
                                  "name": "주문 API 매장"
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
                        .content("{\"businessStatus\":\"OPEN\"}"))
                .andExpect(status().isOk());
    }

    private Long createCategory(String token, Long storeId) throws Exception {
        String response = mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/categories",
                        storeId
                )
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"커피\",\"displayOrder\":0}"))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return ((Number) JsonPath.read(
                response,
                "$.data.categoryId"
        )).longValue();
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
                                  "name": "아메리카노",
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

    private String issueQr(String token, Long storeId) throws Exception {
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
        return JsonPath.read(response, "$.data.token");
    }

    private Cookie openGuestSession(String qrToken) throws Exception {
        MvcResult opened = mockMvc.perform(post(
                        "/api/v1/qr/{token}/sessions",
                        qrToken
                ))
                .andExpect(status().isOk())
                .andReturn();
        return opened.getResponse().getCookie("POPQ_GUEST_SESSION");
    }
}
