package com.example.project_popq.engagement.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.order.domain.Order;
import com.example.project_popq.store.domain.Store;
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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "reviews")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Review extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "review_id")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false, unique = true)
    private Order order;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(name = "rating", nullable = false)
    private int rating;

    @Column(name = "content", length = 1000)
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private ReviewStatus status;

    private Review(Order order, User user, int rating, String content) {
        this.order = order;
        this.user = user;
        this.store = order.getStore();
        this.rating = rating;
        this.content = content;
        this.status = ReviewStatus.ACTIVE;
    }

    public static Review create(
            Order order,
            User user,
            int rating,
            String content
    ) {
        return new Review(order, user, rating, content);
    }

    public void update(int rating, String content) {
        this.rating = rating;
        this.content = content;
    }

    public void delete() {
        this.status = ReviewStatus.DELETED;
        this.content = null;
    }

    public boolean belongsTo(Long userId) {
        return user.getId().equals(userId);
    }
}
