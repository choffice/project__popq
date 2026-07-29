package com.example.project_popq.auth;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = "popq.auth.dev-login-enabled=false")
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DevAuthDisabledIntegrationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void disabledDevLoginIsNotExposed() throws Exception {
        mockMvc.perform(post("/api/v1/dev/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email": "disabled-check@popq.test",
                                  "name": "Disabled Check",
                                  "role": "SELLER"
                                }
                                """))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code")
                        .value("RESOURCE_NOT_FOUND"));
    }
}
