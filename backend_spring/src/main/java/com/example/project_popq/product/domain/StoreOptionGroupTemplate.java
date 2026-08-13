package com.example.project_popq.product.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.store.domain.Store;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
@Table(name = "store_option_group_templates")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreOptionGroupTemplate extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_option_group_template_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Column(name = "min_select", nullable = false)
    private int minSelect;

    @Column(name = "max_select", nullable = false)
    private int maxSelect;

    @Column(name = "is_required", nullable = false)
    private boolean required;

    @Column(name = "version", nullable = false)
    private long version;

    @OneToMany(
            mappedBy = "template",
            cascade = CascadeType.ALL,
            orphanRemoval = true
    )
    @OrderBy("displayOrder ASC, id ASC")
    private List<StoreOptionTemplateOption> options = new ArrayList<>();

    private StoreOptionGroupTemplate(
            Store store,
            String name,
            int minSelect,
            int maxSelect,
            boolean required
    ) {
        this.store = store;
        this.name = name;
        this.minSelect = minSelect;
        this.maxSelect = maxSelect;
        this.required = required;
        this.version = 1L;
    }

    public static StoreOptionGroupTemplate create(
            Store store,
            String name,
            int minSelect,
            int maxSelect,
            boolean required
    ) {
        return new StoreOptionGroupTemplate(
                store, name, minSelect, maxSelect, required
        );
    }

    public void addOption(String name, long additionalPrice, int displayOrder) {
        options.add(StoreOptionTemplateOption.create(
                this, name, additionalPrice, displayOrder
        ));
    }

    public void updateFrom(
            String name,
            int minSelect,
            int maxSelect,
            boolean required,
            List<StoreOptionTemplateOption.Value> optionValues
    ) {
        this.name = name;
        this.minSelect = minSelect;
        this.maxSelect = maxSelect;
        this.required = required;
        this.version += 1L;
        this.options.clear();
        optionValues.forEach(value -> addOption(
                value.name(), value.additionalPrice(), value.displayOrder()
        ));
    }
}
