package com.example.project_popq.engagement;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.UUID;
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
class CustomerEngagementApiIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void customerManagesInterestsReviewAndProfile() throws Exception {
        String suffix = UUID.randomUUID().toString();

        String sellerToken = login(
                "SELLER",
                "seller-" + suffix
        );

        String customerToken = login(
                "CUSTOMER",
                "customer-" + suffix
        );

        String outsiderToken = login(
                "CUSTOMER",
                "outsider-" + suffix
        );

        Long storeId = createOpenStore(sellerToken);
        Long productId = createProduct(sellerToken, storeId);

        mockMvc.perform(
                        get(
                                "/api/v1/customer/store-interests/{storeId}",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.interested")
                                .value(false)
                );

        mockMvc.perform(
                        post(
                                "/api/v1/customer/store-interests/{storeId}",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.interested")
                                .value(true)
                );

        mockMvc.perform(
                        get("/api/v1/customer/store-interests")
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data[0].storeId")
                                .value(storeId)
                )
                .andExpect(
                        jsonPath("$.data[0].representativeCategory")
                                .value("카페")
                )
                .andExpect(
                        jsonPath("$.data[0].imageUrl")
                                .value(
                                        "https://example.test/engagement-cafe.jpg"
                                )
                );

        String orderPublicId = createPaidOrder(
                customerToken,
                storeId,
                productId,
                suffix
        );

        mockMvc.perform(
                        post(
                                "/api/v1/customer/reviews/orders/{orderPublicId}",
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        reviewBody(
                                                5,
                                                "Not completed yet"
                                        )
                                )
                )
                .andExpect(status().isConflict())
                .andExpect(
                        jsonPath("$.error.code")
                                .value("REVIEW_NOT_ALLOWED")
                );

        completeOrder(
                sellerToken,
                storeId,
                orderPublicId
        );

        String reviewResponse = mockMvc.perform(
                        post(
                                "/api/v1/customer/reviews/orders/{orderPublicId}",
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        reviewBody(
                                                5,
                                                "Excellent coffee"
                                        )
                                )
                )
                .andExpect(status().isCreated())
                .andExpect(
                        jsonPath("$.data.status")
                                .value("ACTIVE")
                )
                .andExpect(
                        jsonPath("$.data.storeId")
                                .value(storeId)
                )
                .andExpect(
                        jsonPath("$.data.rating")
                                .value(5)
                )
                .andReturn()
                .getResponse()
                .getContentAsString();

        Long reviewId = ((Number) JsonPath.read(
                reviewResponse,
                "$.data.reviewId"
        )).longValue();

        mockMvc.perform(
                        post(
                                "/api/v1/customer/reviews/orders/{orderPublicId}",
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        reviewBody(
                                                4,
                                                "Duplicate"
                                        )
                                )
                )
                .andExpect(status().isConflict())
                .andExpect(
                        jsonPath("$.error.code")
                                .value("REVIEW_ALREADY_EXISTS")
                );

        mockMvc.perform(
                        get(
                                "/api/v1/public/stores/{storeId}/reviews",
                                storeId
                        )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data[0].reviewId")
                                .value(reviewId)
                )
                .andExpect(
                        jsonPath("$.data[0].content")
                                .value("Excellent coffee")
                );

        mockMvc.perform(
                        put(
                                "/api/v1/customer/reviews/{reviewId}",
                                reviewId
                        )
                                .header(
                                        "Authorization",
                                        bearer(outsiderToken)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        reviewBody(
                                                1,
                                                "Unauthorized"
                                        )
                                )
                )
                .andExpect(status().isNotFound())
                .andExpect(
                        jsonPath("$.error.code")
                                .value("REVIEW_NOT_FOUND")
                );

        mockMvc.perform(
                        put(
                                "/api/v1/customer/reviews/{reviewId}",
                                reviewId
                        )
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        reviewBody(
                                                4,
                                                "Updated review"
                                        )
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.rating")
                                .value(4)
                )
                .andExpect(
                        jsonPath("$.data.content")
                                .value("Updated review")
                );

        mockMvc.perform(
                        get("/api/v1/customer/profile")
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.interestCount")
                                .value(1)
                )
                .andExpect(
                        jsonPath("$.data.reviewCount")
                                .value(1)
                )
                .andExpect(
                        jsonPath("$.data.orderCount")
                                .value(1)
                );

        mockMvc.perform(
                        delete(
                                "/api/v1/customer/reviews/{reviewId}",
                                reviewId
                        )
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.status")
                                .value("DELETED")
                )
                .andExpect(
                        jsonPath("$.data.content")
                                .isEmpty()
                );

        mockMvc.perform(
                        get(
                                "/api/v1/public/stores/{storeId}/reviews",
                                storeId
                        )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data")
                                .isEmpty()
                );

        mockMvc.perform(
                        delete(
                                "/api/v1/customer/store-interests/{storeId}",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.interested")
                                .value(false)
                );

        mockMvc.perform(
                        get("/api/v1/customer/profile")
                                .header(
                                        "Authorization",
                                        bearer(customerToken)
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.interestCount")
                                .value(0)
                )
                .andExpect(
                        jsonPath("$.data.reviewCount")
                                .value(0)
                )
                .andExpect(
                        jsonPath("$.data.orderCount")
                                .value(1)
                );
    }

    private String login(
            String role,
            String identity
    ) throws Exception {

        String response = mockMvc.perform(
                        post("/api/v1/dev/auth/login")
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "email": "%s@popq.test",
                                          "name": "Engagement Test",
                                          "role": "%s"
                                        }
                                        """.formatted(
                                        identity,
                                        role
                                ))
                )
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(
                response,
                "$.data.accessToken"
        );
    }

    private Long createOpenStore(
            String token
    ) throws Exception {

        String response = mockMvc.perform(
                        post("/api/v1/seller/stores")
                                .header(
                                        "Authorization",
                                        bearer(token)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "storeType": "LOCAL_STORE",
                                          "name": "Engagement Cafe",
                                          "representativeCategory": "카페",
                                          "imageUrl": "https://example.test/engagement-cafe.jpg"
                                        }
                                        """)
                )
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        Long storeId = ((Number) JsonPath.read(
                response,
                "$.data.storeId"
        )).longValue();

        mockMvc.perform(
                        patch(
                                "/api/v1/seller/stores/{storeId}/business-status",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        bearer(token)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        "{\"businessStatus\":\"OPEN\"}"
                                )
                )
                .andExpect(status().isOk());

        return storeId;
    }

    private Long createProduct(
            String token,
            Long storeId
    ) throws Exception {

        String categoryResponse = mockMvc.perform(
                        post(
                                "/api/v1/seller/stores/{storeId}/categories",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        bearer(token)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        "{\"name\":\"Coffee\",\"displayOrder\":0}"
                                )
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
                        post(
                                "/api/v1/seller/stores/{storeId}/products",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        bearer(token)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "categoryId": %d,
                                          "name": "Americano",
                                          "basePrice": 5000
                                        }
                                        """.formatted(categoryId))
                )
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return ((Number) JsonPath.read(
                productResponse,
                "$.data.product.productId"
        )).longValue();
    }

    private String createPaidOrder(
            String token,
            Long storeId,
            Long productId,
            String suffix
    ) throws Exception {

        String orderResponse = mockMvc.perform(
                        post(
                                "/api/v1/customer/orders/stores/{storeId}",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        bearer(token)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "idempotencyKey": "review-order-%s",
                                          "orderType": "TAKEOUT",
                                          "items": [{
                                            "productId": %d,
                                            "quantity": 1,
                                            "optionIds": []
                                          }]
                                        }
                                        """.formatted(
                                        suffix,
                                        productId
                                ))
                )
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String orderPublicId = JsonPath.read(
                orderResponse,
                "$.data.orderPublicId"
        );

        mockMvc.perform(
                        post(
                                "/api/v1/customer/orders/{orderPublicId}/payments",
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        bearer(token)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "idempotencyKey": "review-payment-%s",
                                          "simulateFailure": false
                                        }
                                        """.formatted(suffix))
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.orderStatus")
                                .value("PLACED")
                );

        return orderPublicId;
    }

    private void completeOrder(
            String token,
            Long storeId,
            String orderPublicId
    ) throws Exception {

        transition(
                token,
                storeId,
                orderPublicId,
                "accept"
        );

        transition(
                token,
                storeId,
                orderPublicId,
                "ready"
        );

        transition(
                token,
                storeId,
                orderPublicId,
                "complete"
        );
    }

    private void transition(
            String token,
            Long storeId,
            String orderPublicId,
            String command
    ) throws Exception {

        String requestBody =
                "accept".equals(command)
                        ? """
                          {
                            "preparationMinutes": 0,
                            "applyAsStoreDefault": false,
                            "reason": "통합 테스트 주문 접수"
                          }
                          """
                        : "{}";

        mockMvc.perform(
                        post(
                                "/api/v1/seller/stores/{storeId}/orders/{orderId}/{command}",
                                storeId,
                                orderPublicId,
                                command
                        )
                                .header(
                                        "Authorization",
                                        bearer(token)
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(requestBody)
                )
                .andExpect(status().isOk());
    }

    private String reviewBody(
            int rating,
            String content
    ) {
        return """
                {
                  "rating": %d,
                  "content": "%s"
                }
                """.formatted(
                rating,
                content
        );
    }

    private String bearer(
            String token
    ) {
        return "Bearer " + token;
    }
}