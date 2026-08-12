package com.example.project_popq.support.domain;

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
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "support_inquiries")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SupportInquiry extends BaseTimeEntity {

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  @Column(name = "support_inquiry_id")
  private Long id;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "customer_user_id", nullable = false)
  private User customer;

  @Enumerated(EnumType.STRING)
  @Column(name = "category", nullable = false, length = 30)
  private SupportInquiryCategory category;

  @Column(name = "title", nullable = false, length = 200)
  private String title;

  @Enumerated(EnumType.STRING)
  @Column(name = "status", nullable = false, length = 30)
  private SupportInquiryStatus status;

  @Column(name = "answered_at")
  private Instant answeredAt;

  @Column(name = "closed_at")
  private Instant closedAt;

  private SupportInquiry(
      User customer,
      SupportInquiryCategory category,
      String title
  ) {
    this.customer = customer;
    this.category = category;
    this.title = title;
    this.status = SupportInquiryStatus.RECEIVED;
  }

  public static SupportInquiry create(
      User customer,
      SupportInquiryCategory category,
      String title
  ) {
    return new SupportInquiry(
        customer,
        category,
        title
    );
  }

  public void markInProgress() {
    this.status = SupportInquiryStatus.IN_PROGRESS;
  }

  public void markAnswered(Instant now) {
    this.status = SupportInquiryStatus.ANSWERED;

    if (this.answeredAt == null) {
      this.answeredAt = now;
    }
  }

  public void reopen() {
    this.status = SupportInquiryStatus.RECEIVED;
    this.closedAt = null;
  }

  public void close(Instant now) {
    this.status = SupportInquiryStatus.CLOSED;
    this.closedAt = now;
  }

  public boolean isOwnedBy(Long customerUserId) {
    return this.customer.getId().equals(customerUserId);
  }

  public boolean isClosed() {
    return this.status == SupportInquiryStatus.CLOSED;
  }
}