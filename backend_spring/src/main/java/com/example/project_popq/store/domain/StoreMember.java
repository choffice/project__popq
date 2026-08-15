package com.example.project_popq.store.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.user.domain.User;
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
    name = "store_members",
    uniqueConstraints = @UniqueConstraint(
        name = "uq_store_members_store_user",
        columnNames = {"store_id", "user_id"}
    )
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class StoreMember extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "store_member_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 30)
    private StoreRole role;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private StoreMemberStatus status;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    private StoreMember(
        Store store,
        User user,
        StoreRole role
    ) {
        this.store = store;
        this.user = user;
        this.role = role;
        this.status = StoreMemberStatus.ACTIVE;
        this.displayOrder = 0;
    }

    public static StoreMember create(
        Store store,
        User user,
        StoreRole role
    ) {
        return new StoreMember(
            store,
            user,
            role
        );
    }

    public void changeDisplayOrder(int displayOrder) {
        if (displayOrder < 0) {
            throw new IllegalArgumentException(
                "displayOrder must be greater than or equal to 0."
            );
        }

        this.displayOrder = displayOrder;
    }
}