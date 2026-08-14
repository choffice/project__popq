package com.example.project_popq.product.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "product_option_groups")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ProductOptionGroup extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "product_option_group_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "min_select", nullable = false)
    private int minSelect;

    @Column(name = "max_select", nullable = false)
    private int maxSelect;

    @Column(name = "is_required", nullable = false)
    private boolean required;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_option_group_template_id")
    private StoreOptionGroupTemplate storeOptionGroupTemplate;

    @Column(name = "applied_template_version")
    private Long appliedTemplateVersion;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private CatalogStatus status;

    @OneToMany(
            mappedBy = "optionGroup",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    @OrderBy("displayOrder ASC, id ASC")
    private List<ProductOption> options = new ArrayList<>();

    private ProductOptionGroup(
            Product product,
            String name,
            int minSelect,
            int maxSelect,
            boolean required,
            int displayOrder,
            StoreOptionGroupTemplate storeOptionGroupTemplate,
            Long appliedTemplateVersion
    ) {
        this.product = product;
        this.name = name;
        this.minSelect = minSelect;
        this.maxSelect = maxSelect;
        this.required = required;
        this.displayOrder = displayOrder;
        this.storeOptionGroupTemplate = storeOptionGroupTemplate;
        this.appliedTemplateVersion = appliedTemplateVersion;
        this.status = CatalogStatus.ACTIVE;
    }

    public static ProductOptionGroup create(
            Product product,
            String name,
            int minSelect,
            int maxSelect,
            boolean required,
            int displayOrder
    ) {
        return new ProductOptionGroup(
                product,
                name,
                minSelect,
                maxSelect,
                required,
                displayOrder,
                null,
                null
        );
    }

    public static ProductOptionGroup createFromTemplate(
            Product product,
            String name,
            int minSelect,
            int maxSelect,
            boolean required,
            int displayOrder,
            StoreOptionGroupTemplate template,
            Long appliedTemplateVersion
    ) {
        return new ProductOptionGroup(
                product,
                name,
                minSelect,
                maxSelect,
                required,
                displayOrder,
                template,
                appliedTemplateVersion
        );
    }

    public void addOption(String name, long additionalPrice, int displayOrder) {
        options.add(ProductOption.create(this, name, additionalPrice, displayOrder));
    }

    public void applyTemplateValues(
            String name,
            int minSelect,
            int maxSelect,
            boolean required,
            long templateVersion,
            List<StoreOptionTemplateOption.Value> optionValues
    ) {
        this.name = name;
        this.minSelect = minSelect;
        this.maxSelect = maxSelect;
        this.required = required;
        this.appliedTemplateVersion = templateVersion;
        this.options.clear();
        optionValues.forEach(value -> addOption(
                value.name(), value.additionalPrice(), value.displayOrder()
        ));
    }
}
