package com.example.project_popq.support.domain;

import com.example.project_popq.common.domain.BaseTimeEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "support_faqs")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SupportFaq extends BaseTimeEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "support_faq_id")
  private Long id;

  @Column(name = "question", nullable = false, length = 500)
  private String question;

  @Column(name = "answer", nullable = false, length = 3000)
  private String answer;

  @Column(name = "display_order", nullable = false)
  private int displayOrder;

  @Column(name = "view_count", nullable = false)
  private long viewCount;

  @Column(name = "is_popular", nullable = false)
  private boolean popular;

  @Column(name = "is_active", nullable = false)
  private boolean active;

  private SupportFaq(
      String question,
      String answer,
      int displayOrder,
      boolean popular
  ) {
    this.question = question;
    this.answer = answer;
    this.displayOrder = displayOrder;
    this.viewCount = 0L;
    this.popular = popular;
    this.active = true;
  }

  public static SupportFaq create(
      String question,
      String answer,
      int displayOrder,
      boolean popular
  ) {
    return new SupportFaq(
        question,
        answer,
        displayOrder,
        popular
    );
  }

  public void update(
      String question,
      String answer,
      int displayOrder,
      boolean popular
  ) {
    this.question = question;
    this.answer = answer;
    this.displayOrder = displayOrder;
    this.popular = popular;
  }

  public void activate() {
    this.active = true;
  }

  public void deactivate() {
    this.active = false;
  }

  public void increaseViewCount() {
    this.viewCount++;
  }
}