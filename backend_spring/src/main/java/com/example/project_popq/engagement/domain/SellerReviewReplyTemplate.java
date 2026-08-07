package com.example.project_popq.engagement.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import com.example.project_popq.store.domain.Store;
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
@Table(name = "seller_review_reply_templates")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SellerReviewReplyTemplate extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "seller_review_reply_template_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(name = "content", nullable = false, length = 1000)
    private String content;

    private SellerReviewReplyTemplate(Store store, String content) {
        this.store = store;
        this.content = content;
    }

    public static SellerReviewReplyTemplate create(Store store, String content) {
        return new SellerReviewReplyTemplate(store, content);
    }

    public void update(String content) {
        this.content = content;
    }
}
