package com.example.project_popq.engagement.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.user.domain.User;
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
        name = "store_interests",
        uniqueConstraints = @UniqueConstraint(
                name = "uq_store_interests_user_store",
                columnNames = {"user_id", "store_id"}
        )
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreInterest extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_interest_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    private StoreInterest(User user, Store store) {
        this.user = user;
        this.store = store;
    }

    public static StoreInterest create(User user, Store store) {
        return new StoreInterest(user, store);
    }
}
