package com.example.project_popq.product.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "store_option_template_options")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreOptionTemplateOption extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_option_template_option_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_option_group_template_id", nullable = false)
    private StoreOptionGroupTemplate template;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "additional_price", nullable = false)
    private long additionalPrice;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    private StoreOptionTemplateOption(
            StoreOptionGroupTemplate template,
            String name,
            long additionalPrice,
            int displayOrder
    ) {
        this.template = template;
        this.name = name;
        this.additionalPrice = additionalPrice;
        this.displayOrder = displayOrder;
    }

    public static StoreOptionTemplateOption create(
            StoreOptionGroupTemplate template,
            String name,
            long additionalPrice,
            int displayOrder
    ) {
        return new StoreOptionTemplateOption(
                template, name, additionalPrice, displayOrder
        );
    }

    public record Value(String name, long additionalPrice, int displayOrder) {
    }
}
