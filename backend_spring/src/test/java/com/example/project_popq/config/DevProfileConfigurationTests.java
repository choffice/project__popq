package com.example.project_popq.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

class DevProfileConfigurationTests {

    private static final String DEV_LOGIN_PROPERTY =
            "popq.auth.dev-login-enabled";

    private final ApplicationContextRunner contextRunner =
            new ApplicationContextRunner()
                    .withInitializer(
                            new ConfigDataApplicationContextInitializer()
                    )
                    .withPropertyValues("spring.profiles.active=dev");

    @Test
    void devLoginIsDisabledByDefaultInDevProfile() {
        contextRunner.run(context ->
                assertThat(context.getEnvironment().getProperty(
                        DEV_LOGIN_PROPERTY,
                        Boolean.class
                )).isFalse()
        );
    }

    @Test
    void devLoginCanBeEnabledExplicitlyForLocalSmokeTests() {
        contextRunner
                .withPropertyValues("POPQ_DEV_LOGIN_ENABLED=true")
                .run(context ->
                        assertThat(context.getEnvironment().getProperty(
                                DEV_LOGIN_PROPERTY,
                                Boolean.class
                        )).isTrue()
                );
    }
}
