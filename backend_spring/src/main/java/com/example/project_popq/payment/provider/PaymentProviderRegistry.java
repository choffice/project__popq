package com.example.project_popq.payment.provider;

import com.example.project_popq.payment.domain.PaymentProviderType;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

@Component
public class PaymentProviderRegistry {

    private final Map<PaymentProviderType, PaymentProvider> providers;

    public PaymentProviderRegistry(
            List<PaymentProvider> paymentProviders
    ) {
        Map<PaymentProviderType, PaymentProvider> registry =
                new EnumMap<>(PaymentProviderType.class);

        for (PaymentProvider paymentProvider : paymentProviders) {
            PaymentProviderType providerType =
                    paymentProvider.providerType();

            PaymentProvider previous = registry.put(
                    providerType,
                    paymentProvider
            );

            if (previous != null) {
                throw new IllegalStateException(
                        "Duplicate PaymentProvider bean for provider type: "
                                + providerType
                );
            }
        }

        this.providers = Map.copyOf(registry);
    }

    public PaymentProvider get(
            PaymentProviderType providerType
    ) {
        PaymentProvider paymentProvider = providers.get(providerType);

        if (paymentProvider == null) {
            throw new IllegalStateException(
                    "PaymentProvider is not configured for provider type: "
                            + providerType
            );
        }

        return paymentProvider;
    }
}