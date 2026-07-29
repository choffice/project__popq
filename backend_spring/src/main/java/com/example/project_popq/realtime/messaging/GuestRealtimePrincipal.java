package com.example.project_popq.realtime.messaging;

import java.security.Principal;

public record GuestRealtimePrincipal(Long guestSessionId) implements Principal {

    private static final String PREFIX = "guest:";

    @Override
    public String getName() {
        return nameOf(guestSessionId);
    }

    public static String nameOf(Long guestSessionId) {
        return PREFIX + guestSessionId;
    }
}
