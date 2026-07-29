package com.example.project_popq.store.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
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
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(
        name = "store_tables",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_store_tables_store_code",
                columnNames = {"store_id", "table_code"}
        )
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreTable extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_table_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(name = "table_code", nullable = false, length = 50)
    private String tableCode;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private StoreTableStatus status;

    private StoreTable(Store store, String tableCode, String name) {
        this.store = store;
        this.tableCode = tableCode;
        this.name = name;
        this.status = StoreTableStatus.ACTIVE;
    }

    public static StoreTable create(Store store, String tableCode, String name) {
        return new StoreTable(store, tableCode, name);
    }

    public boolean isActive() {
        return status == StoreTableStatus.ACTIVE;
    }
}

