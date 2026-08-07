package com.example.project_popq.store;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
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
class PublicStoreApiIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void anonymousCustomerCanSearchOpenStoresByQueryTagAndDistance()
            throws Exception {
        String accessToken = loginSeller();
        Long openStoreId = createStore(
                accessToken,
                "성수 커피 연구소",
                "서울 성동구 연무장길",
                37.5445,
                127.0560,
                "coffee"
        );
        openStore(accessToken, openStoreId);
        createStore(
                accessToken,
                "아직 준비 중인 가게",
                "서울 성동구",
                37.5446,
                127.0561,
                "coffee"
        );

        mockMvc.perform(get("/api/v1/public/stores")
                        .queryParam("query", "성수")
                        .queryParam("tag", "coffee")
                        .queryParam("latitude", "37.5444")
                        .queryParam("longitude", "127.0559")
                        .queryParam("radiusKm", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].storeId").value(openStoreId))
                .andExpect(jsonPath("$.data[0].name").value("성수 커피 연구소"))
                .andExpect(jsonPath("$.data[0].representativeCategory").value("카페"))
                .andExpect(jsonPath("$.data[0].imageUrl")
                        .value("https://example.test/store.jpg"))
                .andExpect(jsonPath("$.data[0].tags[0]").value("coffee"))
                .andExpect(jsonPath("$.data[0].distanceMeters").isNumber());
    }

    @Test
    void publicDetailExposesPreparingAndOpenActiveStore() throws Exception {
        String accessToken = loginSeller();
        Long storeId = createStore(
                accessToken,
                "상세 매장",
                "서울 마포구",
                37.5550,
                126.9220,
                "dessert"
        );

        mockMvc.perform(get("/api/v1/public/stores/{storeId}", storeId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.businessStatus").value("PRE_OPEN"));

        openStore(accessToken, storeId);

        mockMvc.perform(get("/api/v1/public/stores/{storeId}", storeId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.storeId").value(storeId))
                .andExpect(jsonPath("$.data.address").value("서울 마포구"))
                .andExpect(jsonPath("$.data.detailAddress").value("2층"))
                .andExpect(jsonPath("$.data.representativeCategory").value("카페"))
                .andExpect(jsonPath("$.data.imageUrl")
                        .value("https://example.test/store.jpg"))
                .andExpect(jsonPath("$.data.phone").value("02-1234-5678"))
                .andExpect(jsonPath("$.data.openTime").value("09:00:00"))
                .andExpect(jsonPath("$.data.closeTime").value("21:00:00"))
                .andExpect(jsonPath("$.data.closedDays[0]").value("MONDAY"))
                .andExpect(jsonPath("$.data.takeoutAvailable").value(true))
                .andExpect(jsonPath("$.data.dineInAvailable").value(false))
                .andExpect(jsonPath("$.data.orderAcceptingEnabled").value(true))
                .andExpect(jsonPath("$.data.tags[0]").value("dessert"));
    }

    @Test
    void publicSearchIncludesPreparingActiveStore() throws Exception {
        String accessToken = loginSeller();
        Long storeId = createStore(
                accessToken,
                "Preparing Discovery Store",
                "Busan",
                35.1578,
                129.0592,
                "preparing-discovery"
        );

        mockMvc.perform(get("/api/v1/public/stores")
                        .queryParam("query", "Preparing Discovery Store")
                        .queryParam("tag", "preparing-discovery")
                        .queryParam("latitude", "35.1578")
                        .queryParam("longitude", "129.0592")
                        .queryParam("radiusKm", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].storeId").value(storeId))
                .andExpect(jsonPath("$.data[0].businessStatus").value("PRE_OPEN"));
    }

    @Test
    void radiusRequiresCompleteLocation() throws Exception {
        mockMvc.perform(get("/api/v1/public/stores")
                        .queryParam("latitude", "37.5")
                        .queryParam("radiusKm", "2"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("INVALID_REQUEST"));
    }

    private String loginSeller() throws Exception {
        String response = mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "discovery-seller@popq.test",
                                  "name": "탐색 API 판매자",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return JsonPath.read(response, "$.data.accessToken");
    }

    private Long createStore(
            String token,
            String name,
            String address,
            double latitude,
            double longitude,
            String tag
    ) throws Exception {
        String response = mockMvc.perform(post("/api/v1/seller/stores")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "storeType": "LOCAL_STORE",
                                  "name": "%s",
                                  "description": "동네에서 만나는 좋은 경험",
                                  "address": "%s",
                                  "detailAddress": "2층",
                                  "representativeCategory": "카페",
                                  "imageUrl": "https://example.test/store.jpg",
                                  "phone": "02-1234-5678",
                                  "latitude": %s,
                                  "longitude": %s,
                                  "openTime": "09:00:00",
                                  "closeTime": "21:00:00",
                                  "closedDays": ["MONDAY"],
                                  "takeoutAvailable": true,
                                  "dineInAvailable": false,
                                  "orderAcceptingEnabled": true,
                                  "tags": ["%s"]
                                }
                                """.formatted(
                                        name,
                                        address,
                                        latitude,
                                        longitude,
                                        tag
                                )))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return ((Number) JsonPath.read(
                response,
                "$.data.storeId"
        )).longValue();
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
}
