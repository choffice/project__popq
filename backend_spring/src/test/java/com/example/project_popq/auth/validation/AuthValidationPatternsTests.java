package com.example.project_popq.auth.validation;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

class AuthValidationPatternsTests {

    private static final Pattern EMAIL = Pattern.compile(AuthValidationPatterns.EMAIL);

    @Test
    void acceptsCompleteEmailAddresses() {
        assertThat(EMAIL.matcher("user@example.com").matches()).isTrue();
        assertThat(EMAIL.matcher("name.tag+1@sub.example.co.kr").matches()).isTrue();
    }

    @Test
    void rejectsIncompleteOrMalformedEmailAddresses() {
        for (String value : List.of(
                "@",
                "user@",
                "@example.com",
                "user@example",
                "user..name@example.com",
                "user@-example.com",
                "user@example.c"
        )) {
            assertThat(EMAIL.matcher(value).matches()).as(value).isFalse();
        }
    }
}
