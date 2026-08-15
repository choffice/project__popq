package com.example.project_popq.order;

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
class CustomerOrderApiIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void customerBrowsesCatalogCreatesPaymentAndRestoresOrder()
            throws Exception {

        String suffix = UUID.randomUUID().toString();

        String sellerToken = login(
                "SELLER",
                "seller-" + suffix
        );

        String customerToken = login(
                "CUSTOMER",
                "customer-" + suffix
        );

        Long storeId = createStore(sellerToken);

        openStore(
                sellerToken,
                storeId
        );

        Long categoryId = createCategory(
                sellerToken,
                storeId
        );

        Long productId = createProduct(
                sellerToken,
                storeId,
                categoryId
        );

        Long optionId = createOptions(
                sellerToken,
                storeId,
                productId
        );

        mockMvc.perform(
                        get(
                                "/api/v1/public/stores/{storeId}/products",
                                storeId
                        )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data[0].productId")
                                .value(productId)
                )
                .andExpect(
                        jsonPath("$.data[0].availableForCustomerApp")
                                .value(true)
                );

        mockMvc.perform(
                        get(
                                "/api/v1/public/stores/{storeId}/products/{productId}",
                                storeId,
                                productId
                        )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.optionGroups[0].name")
                                .value("온도")
                )
                .andExpect(
                        jsonPath(
                                "$.data.optionGroups[0].options[0].optionId"
                        ).value(optionId)
                );

        String orderKey =
                "customer-order-" + suffix;

        String orderResponse = mockMvc.perform(
                        post(
                                "/api/v1/customer/orders/stores/{storeId}",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + customerToken
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "idempotencyKey": "%s",
                                          "orderType": "TAKEOUT",
                                          "items": [{
                                            "productId": %d,
                                            "quantity": 2,
                                            "optionIds": [%d]
                                          }]
                                        }
                                        """.formatted(
                                        orderKey,
                                        productId,
                                        optionId
                                ))
                )
                .andExpect(status().isCreated())
                .andExpect(
                        jsonPath("$.data.status")
                                .value("CREATED")
                )
                .andExpect(
                        jsonPath("$.data.totalAmount")
                                .value(11_000)
                )
                .andReturn()
                .getResponse()
                .getContentAsString();

        String orderPublicId = JsonPath.read(
                orderResponse,
                "$.data.orderPublicId"
        );

        mockMvc.perform(
                        post(
                                "/api/v1/customer/orders/{orderId}/payments",
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + customerToken
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "idempotencyKey": "customer-payment-%s",
                                          "simulateFailure": false
                                        }
                                        """.formatted(suffix))
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.status")
                                .value("PAID")
                )
                .andExpect(
                        jsonPath("$.data.orderStatus")
                                .value("PLACED")
                );

        /*
         * 결제 직후에는 포인트가 적립되지 않아야 한다.
         */
        mockMvc.perform(
                        get("/api/v1/customer/points")
                                .header(
                                        "Authorization",
                                        "Bearer " + customerToken
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.balance")
                                .value(0)
                );

        mockMvc.perform(
                        get("/api/v1/customer/orders")
                                .header(
                                        "Authorization",
                                        "Bearer " + customerToken
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data[0].orderPublicId")
                                .value(orderPublicId)
                )
                .andExpect(
                        jsonPath("$.data[0].status")
                                .value("PLACED")
                );

        /*
         * 현재 주문 접수 API는 접수 시 예상 준비시간 등의
         * 요청 데이터를 받는다.
         */
        mockMvc.perform(
                        post(
                                "/api/v1/seller/stores/{storeId}/orders/{orderId}/accept",
                                storeId,
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + sellerToken
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "preparationMinutes": 0,
                                          "applyAsStoreDefault": false,
                                          "reason": "통합 테스트 주문 접수"
                                        }
                                        """)
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.status")
                                .value("PREPARING")
                );

        mockMvc.perform(
                        get(
                                "/api/v1/customer/orders/{orderId}/sync",
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + customerToken
                                )
                                .queryParam(
                                        "knownVersion",
                                        "1"
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.refreshRequired")
                                .value(true)
                )
                .andExpect(
                        jsonPath("$.data.order.status")
                                .value("PREPARING")
                );

        mockMvc.perform(
                        post(
                                "/api/v1/seller/stores/{storeId}/orders/{orderId}/ready",
                                storeId,
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + sellerToken
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("{}")
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.status")
                                .value("READY")
                );

        /*
         * READY 상태에서도 아직 실제 상품 수령 전이므로
         * 포인트가 적립되지 않아야 한다.
         */
        mockMvc.perform(
                        get("/api/v1/customer/points")
                                .header(
                                        "Authorization",
                                        "Bearer " + customerToken
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.balance")
                                .value(0)
                );

        mockMvc.perform(
                        post(
                                "/api/v1/seller/stores/{storeId}/orders/{orderId}/complete",
                                storeId,
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + sellerToken
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("{}")
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.status")
                                .value("COMPLETED")
                );

        /*
         * 주문이 COMPLETED 된 시점에 결제금액 11,000원의
         * 2.5%인 275P가 적립되어야 한다.
         */
        mockMvc.perform(
                        get("/api/v1/customer/points")
                                .header(
                                        "Authorization",
                                        "Bearer " + customerToken
                                )
                )
                .andExpect(status().isOk())
                .andExpect(
                        jsonPath("$.data.balance")
                                .value(275)
                );
    }

    @Test
    void customerCannotReadAnotherCustomersOrder()
            throws Exception {

        String suffix = UUID.randomUUID().toString();

        String sellerToken = login(
                "SELLER",
                "seller-owner-" + suffix
        );

        String ownerToken = login(
                "CUSTOMER",
                "owner-" + suffix
        );

        String outsiderToken = login(
                "CUSTOMER",
                "outsider-" + suffix
        );

        Long storeId = createStore(sellerToken);

        openStore(
                sellerToken,
                storeId
        );

        Long categoryId = createCategory(
                sellerToken,
                storeId
        );

        Long productId = createProduct(
                sellerToken,
                storeId,
                categoryId
        );

        String response = mockMvc.perform(
                        post(
                                "/api/v1/customer/orders/stores/{storeId}",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + ownerToken
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "idempotencyKey": "owner-order-%s",
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
                response,
                "$.data.orderPublicId"
        );

        mockMvc.perform(
                        get(
                                "/api/v1/customer/orders/{orderId}",
                                orderPublicId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + outsiderToken
                                )
                )
                .andExpect(status().isNotFound())
                .andExpect(
                        jsonPath("$.error.code")
                                .value("ORDER_NOT_FOUND")
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
                                          "name": "회원 주문 테스트",
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

    private Long createStore(
            String token
    ) throws Exception {

        String response = mockMvc.perform(
                        post("/api/v1/seller/stores")
                                .header(
                                        "Authorization",
                                        "Bearer " + token
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "storeType": "LOCAL_STORE",
                                          "name": "회원 주문 매장"
                                        }
                                        """)
                )
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return ((Number) JsonPath.read(
                response,
                "$.data.storeId"
        )).longValue();
    }

    private void openStore(
            String token,
            Long storeId
    ) throws Exception {

        mockMvc.perform(
                        patch(
                                "/api/v1/seller/stores/{storeId}/business-status",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + token
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        "{\"businessStatus\":\"OPEN\"}"
                                )
                )
                .andExpect(status().isOk());
    }

    private Long createCategory(
            String token,
            Long storeId
    ) throws Exception {

        String response = mockMvc.perform(
                        post(
                                "/api/v1/seller/stores/{storeId}/categories",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + token
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content(
                                        "{\"name\":\"커피\",\"displayOrder\":0}"
                                )
                )
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

        String response = mockMvc.perform(
                        post(
                                "/api/v1/seller/stores/{storeId}/products",
                                storeId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + token
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "categoryId": %d,
                                          "name": "회원 아메리카노",
                                          "basePrice": 5000
                                        }
                                        """.formatted(categoryId))
                )
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return ((Number) JsonPath.read(
                response,
                "$.data.product.productId"
        )).longValue();
    }

    private Long createOptions(
            String token,
            Long storeId,
            Long productId
    ) throws Exception {

        String response = mockMvc.perform(
                        put(
                                "/api/v1/seller/stores/{storeId}/products/{productId}/options",
                                storeId,
                                productId
                        )
                                .header(
                                        "Authorization",
                                        "Bearer " + token
                                )
                                .contentType(
                                        MediaType.APPLICATION_JSON
                                )
                                .content("""
                                        {
                                          "groups": [{
                                            "name": "온도",
                                            "minSelect": 1,
                                            "maxSelect": 1,
                                            "required": true,
                                            "displayOrder": 0,
                                            "options": [{
                                              "name": "아이스",
                                              "additionalPrice": 500,
                                              "displayOrder": 0
                                            }]
                                          }]
                                        }
                                        """)
                )
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return ((Number) JsonPath.read(
                response,
                "$.data.optionGroups[0].options[0].optionId"
        )).longValue();
    }
}