package com.example.project_popq.product.dto;

import com.example.project_popq.product.domain.StoreOptionGroupTemplate;
import com.example.project_popq.product.domain.StoreOptionTemplateOption;
import java.util.List;

public record StoreOptionTemplateResponse(
        Long templateId,
        Long storeId,
        String name,
        int minSelect,
        int maxSelect,
        boolean required,
        long version,
        List<OptionResponse> options
) {
    public static StoreOptionTemplateResponse from(
            StoreOptionGroupTemplate template
    ) {
        return new StoreOptionTemplateResponse(
                template.getId(),
                template.getStore().getId(),
                template.getName(),
                template.getMinSelect(),
                template.getMaxSelect(),
                template.isRequired(),
                template.getVersion(),
                template.getOptions().stream().map(OptionResponse::from).toList()
        );
    }

    public record OptionResponse(
            Long optionId,
            String name,
            long additionalPrice,
            int displayOrder
    ) {
        private static OptionResponse from(StoreOptionTemplateOption option) {
            return new OptionResponse(
                    option.getId(),
                    option.getName(),
                    option.getAdditionalPrice(),
                    option.getDisplayOrder()
            );
        }
    }
}
