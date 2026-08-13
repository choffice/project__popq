package com.example.project_popq.product.dto;

import com.example.project_popq.product.domain.Product;
import com.example.project_popq.product.domain.ProductOption;
import com.example.project_popq.product.domain.ProductOptionGroup;
import java.time.Instant;
import java.util.List;

public record ProductDetailResponse(
        ProductSummaryResponse product,
        AvailabilityResponse availability,
        List<OptionGroupResponse> optionGroups
) {
    public static ProductDetailResponse from(Product product, Instant now) {
        return new ProductDetailResponse(
                ProductSummaryResponse.from(product, now),
                AvailabilityResponse.from(product),
                product.getOptionGroups().stream()
                        .map(OptionGroupResponse::from)
                        .toList()
        );
    }

    public record AvailabilityResponse(
            boolean soldOut,
            Instant salesStartAt,
            Instant salesEndAt,
            boolean qrWebEnabled,
            boolean customerAppEnabled
    ) {
        private static AvailabilityResponse from(Product product) {
            return new AvailabilityResponse(
                    product.getAvailability().isSoldOut(),
                    product.getAvailability().getSalesStartAt(),
                    product.getAvailability().getSalesEndAt(),
                    product.getAvailability().isQrWebEnabled(),
                    product.getAvailability().isCustomerAppEnabled()
            );
        }
    }

    public record OptionGroupResponse(
            Long optionGroupId,
            String name,
            int minSelect,
            int maxSelect,
            boolean required,
            int displayOrder,
            Long templateId,
            Long appliedTemplateVersion,
            List<OptionResponse> options
    ) {
        private static OptionGroupResponse from(ProductOptionGroup group) {
            return new OptionGroupResponse(
                    group.getId(),
                    group.getName(),
                    group.getMinSelect(),
                    group.getMaxSelect(),
                    group.isRequired(),
                    group.getDisplayOrder(),
                    group.getStoreOptionGroupTemplate() == null
                            ? null
                            : group.getStoreOptionGroupTemplate().getId(),
                    group.getAppliedTemplateVersion(),
                    group.getOptions().stream()
                            .map(OptionResponse::from)
                            .toList()
            );
        }
    }

    public record OptionResponse(
            Long optionId,
            String name,
            long additionalPrice,
            int displayOrder
    ) {
        private static OptionResponse from(ProductOption option) {
            return new OptionResponse(
                    option.getId(),
                    option.getName(),
                    option.getAdditionalPrice(),
                    option.getDisplayOrder()
            );
        }
    }
}
