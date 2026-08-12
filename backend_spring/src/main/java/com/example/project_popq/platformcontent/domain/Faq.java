package com.example.project_popq.platformcontent.domain;

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
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "faqs")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Faq extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "faq_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "audience", nullable = false, length = 30)
    private AppAudience audience;

    @Column(name = "category", nullable = false, length = 50)
    private String category;

    @Column(name = "question", nullable = false, length = 300)
    private String question;

    @Column(name = "answer", nullable = false, length = 4000)
    private String answer;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private ContentStatus status;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "author_user_id", nullable = false)
    private User author;

    private Faq(
            User author,
            AppAudience audience,
            String category,
            String question,
            String answer,
            int displayOrder
    ) {
        this.author = author;
        this.status = ContentStatus.DRAFT;
        update(audience, category, question, answer, displayOrder);
    }

    public static Faq create(
            User author,
            AppAudience audience,
            String category,
            String question,
            String answer,
            int displayOrder
    ) {
        return new Faq(author, audience, category, question, answer, displayOrder);
    }

    public void update(
            AppAudience audience,
            String category,
            String question,
            String answer,
            int displayOrder
    ) {
        this.audience = audience;
        this.category = category.trim();
        this.question = question.trim();
        this.answer = answer.trim();
        this.displayOrder = displayOrder;
    }

    public void changeStatus(ContentStatus status) {
        this.status = status;
    }
}
