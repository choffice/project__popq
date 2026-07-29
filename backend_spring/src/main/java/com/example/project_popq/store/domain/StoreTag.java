package com.example.project_popq.store.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.product.domain.Tag;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(
        name = "store_tags",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_store_tags_store_tag",
                columnNames = {"store_id", "tag_id"}
        )
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreTag extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_tag_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tag_id", nullable = false)
    private Tag tag;

    private StoreTag(Store store, Tag tag) {
        this.store = store;
        this.tag = tag;
    }

    public static StoreTag create(Store store, Tag tag) {
        return new StoreTag(store, tag);
    }
}
