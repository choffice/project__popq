package com.example.project_popq.notification;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
class CustomerNotificationApiIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void customerRegistersDeviceAndReadsOrderNotification() throws Exception {
        String suffix = UUID.randomUUID().toString();
        String sellerToken = login("SELLER", "seller-" + suffix);
        String customerToken = login("CUSTOMER", "customer-" + suffix);
        String outsiderToken = login("CUSTOMER", "outsider-" + suffix);
        String deviceToken = "fcm-device-" + suffix;

        String deviceResponse = mockMvc.perform(post(
                        "/api/v1/customer/devices"
                )
                        .header("Authorization", bearer(customerToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token": "%s",
                                  "platform": "ANDROID"
                                }
                                """.formatted(deviceToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.platform").value("ANDROID"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        Long deviceId = number(deviceResponse, "$.data.deviceId");

        mockMvc.perform(post("/api/v1/customer/devices")
                        .header("Authorization", bearer(customerToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "token": "%s",
                                  "platform": "ANDROID"
                                }
                                """.formatted(deviceToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deviceId").value(deviceId));

        mockMvc.perform(get("/api/v1/customer/devices")
                        .header("Authorization", bearer(customerToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].deviceId").value(deviceId));

        Long storeId = createOpenStore(sellerToken);
        Long productId = createProduct(sellerToken, storeId);
        String orderPublicId = createPaidOrder(
                customerToken,
                storeId,
                productId,
                suffix
        );

        String notificationResponse = mockMvc.perform(get(
                        "/api/v1/customer/notifications"
                ).header("Authorization", bearer(customerToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].type")
                        .value("ORDER_STATUS"))
                .andExpect(jsonPath("$.data[0].targetType").value("ORDER"))
                .andExpect(jsonPath("$.data[0].targetId")
                        .value(orderPublicId))
                .andExpect(jsonPath("$.data[0].deepLink")
                        .value("/orders/" + orderPublicId))
                .andExpect(jsonPath("$.data[0].read").value(false))
                .andReturn()
                .getResponse()
                .getContentAsString();
        Long notificationId = number(
                notificationResponse,
                "$.data[0].notificationId"
        );

        mockMvc.perform(get(
                        "/api/v1/customer/notifications/unread-count"
                ).header("Authorization", bearer(customerToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.unreadCount").value(1));

        mockMvc.perform(post(
                        "/api/v1/customer/notifications/{id}/read",
                        notificationId
                ).header("Authorization", bearer(outsiderToken)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code")
                        .value("NOTIFICATION_NOT_FOUND"));

        mockMvc.perform(post(
                        "/api/v1/customer/notifications/{id}/read",
                        notificationId
                ).header("Authorization", bearer(customerToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.read").value(true));

        mockMvc.perform(get(
                        "/api/v1/customer/notifications"
                )
                        .header("Authorization", bearer(customerToken))
                        .queryParam("unreadOnly", "true"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data").isEmpty());

        mockMvc.perform(delete(
                        "/api/v1/customer/devices/{deviceId}",
                        deviceId
                ).header("Authorization", bearer(outsiderToken)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code")
                        .value("PUSH_DEVICE_NOT_FOUND"));

        mockMvc.perform(delete(
                        "/api/v1/customer/devices/{deviceId}",
                        deviceId
                ).header("Authorization", bearer(customerToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.deviceId").value(deviceId));

        mockMvc.perform(get("/api/v1/customer/devices")
                        .header("Authorization", bearer(customerToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data").isEmpty());
    }

    private String login(String role, String identity) throws Exception {
        String response = mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "%s@popq.test",
                                  "name": "Notification Test",
                                  "role": "%s"
                                }
                                """.formatted(identity, role)))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.accessToken");
    }

    private Long createOpenStore(String token) throws Exception {
        String response = mockMvc.perform(post("/api/v1/seller/stores")
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "storeType": "LOCAL_STORE",
                                  "name": "Notification Cafe"
                                }
                                """))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        Long storeId = number(response, "$.data.storeId");
        mockMvc.perform(patch(
                        "/api/v1/seller/stores/{storeId}/business-status",
                        storeId
                )
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"businessStatus\":\"OPEN\"}"))
                .andExpect(status().isOk());
        return storeId;
    }

    private Long createProduct(String token, Long storeId) throws Exception {
        String categoryResponse = mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/categories",
                        storeId
                )
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Coffee\",\"displayOrder\":0}"))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        Long categoryId = number(categoryResponse, "$.data.categoryId");
        String productResponse = mockMvc.perform(post(
                        "/api/v1/seller/stores/{storeId}/products",
                        storeId
                )
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "categoryId": %d,
                                  "name": "Americano",
                                  "basePrice": 5000
                                }
                                """.formatted(categoryId)))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return number(productResponse, "$.data.product.productId");
    }

    private String createPaidOrder(
            String token,
            Long storeId,
            Long productId,
            String suffix
    ) throws Exception {
        String orderResponse = mockMvc.perform(post(
                        "/api/v1/customer/orders/stores/{storeId}",
                        storeId
                )
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idempotencyKey": "notification-order-%s",
                                  "orderType": "TAKEOUT",
                                  "items": [{
                                    "productId": %d,
                                    "quantity": 1,
                                    "optionIds": []
                                  }]
                                }
                                """.formatted(suffix, productId)))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String orderPublicId = JsonPath.read(
                orderResponse,
                "$.data.orderPublicId"
        );
        mockMvc.perform(post(
                        "/api/v1/customer/orders/{orderPublicId}/payments",
                        orderPublicId
                )
                        .header("Authorization", bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "idempotencyKey": "notification-payment-%s",
                                  "simulateFailure": false
                                }
                                """.formatted(suffix)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.orderStatus").value("PLACED"));
        return orderPublicId;
    }

    private Long number(String response, String path) {
        return ((Number) JsonPath.read(response, path)).longValue();
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }
}
