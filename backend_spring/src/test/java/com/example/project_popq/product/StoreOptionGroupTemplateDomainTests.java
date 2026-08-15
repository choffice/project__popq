package com.example.project_popq.product;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotSame;

import com.example.project_popq.product.domain.Product;
import com.example.project_popq.product.domain.ProductCategory;
import com.example.project_popq.product.domain.ProductOptionGroup;
import com.example.project_popq.product.domain.StoreOptionGroupTemplate;
import com.example.project_popq.product.domain.StoreOptionTemplateOption;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreType;
import java.util.List;
import org.junit.jupiter.api.Test;

class StoreOptionGroupTemplateDomainTests {

    @Test
    void copiedProductGroupsRemainIndependentUntilExplicitApply() {
        Store store = Store.create(StoreType.LOCAL_STORE, "카페", null);
        ProductCategory category = ProductCategory.create(store, "음료", 0);
        Product americano = Product.create(
                store, category, "아메리카노", null, null, 3_000L
        );
        Product latte = Product.create(
                store, category, "카페라떼", null, null, 4_000L
        );
        StoreOptionGroupTemplate template = StoreOptionGroupTemplate.create(
                store, "온도", 1, 1, true
        );
        template.addOption("HOT", 0L, 0);
        template.addOption("ICE", 0L, 1);

        ProductOptionGroup americanoTemperature = ProductOptionGroup.createFromTemplate(
                americano, "온도", 1, 1, true, 0, template, 1L
        );
        americanoTemperature.addOption("HOT", 0L, 0);
        americanoTemperature.addOption("ICE", 0L, 1);
        ProductOptionGroup latteTemperature = ProductOptionGroup.createFromTemplate(
                latte, "온도", 1, 1, true, 0, template, 1L
        );
        latteTemperature.addOption("HOT", 0L, 0);
        latteTemperature.addOption("ICE", 0L, 1);

        latteTemperature.applyTemplateValues(
                "온도", 1, 1, true, 1L,
                List.of(
                        new StoreOptionTemplateOption.Value("HOT", 0L, 0),
                        new StoreOptionTemplateOption.Value("ICE", 500L, 1)
                )
        );

        assertNotSame(americanoTemperature, latteTemperature);
        assertNotSame(
                americanoTemperature.getOptions().get(1),
                latteTemperature.getOptions().get(1)
        );
        assertEquals(0L, americanoTemperature.getOptions().get(1).getAdditionalPrice());
        assertEquals(500L, latteTemperature.getOptions().get(1).getAdditionalPrice());
        assertEquals(0L, template.getOptions().get(1).getAdditionalPrice());
    }

    @Test
    void explicitTemplateUpdateIncrementsVersionAndReplacesTemplateOptions() {
        Store store = Store.create(StoreType.LOCAL_STORE, "카페", null);
        StoreOptionGroupTemplate template = StoreOptionGroupTemplate.create(
                store, "온도", 1, 1, true
        );
        template.addOption("HOT", 0L, 0);
        template.addOption("ICE", 0L, 1);

        template.updateFrom(
                "온도", 1, 1, true,
                List.of(
                        new StoreOptionTemplateOption.Value("HOT", 0L, 0),
                        new StoreOptionTemplateOption.Value("ICE", 500L, 1)
                )
        );

        assertEquals(2L, template.getVersion());
        assertEquals(2, template.getOptions().size());
        assertEquals(500L, template.getOptions().get(1).getAdditionalPrice());
    }
}
