package com.example.project_popq.support.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.support.domain.SupportInquiry;
import com.example.project_popq.support.domain.SupportInquiryMessage;
import com.example.project_popq.support.domain.SupportInquiryStatus;
import com.example.project_popq.support.domain.SupportMessageSenderType;
import com.example.project_popq.support.dto.ChangeSupportInquiryStatusRequest;
import com.example.project_popq.support.dto.SendSupportMessageRequest;
import com.example.project_popq.support.dto.SupportInquiryDetailResponse;
import com.example.project_popq.support.dto.SupportInquirySummaryResponse;
import com.example.project_popq.support.repository.SupportInquiryMessageRepository;
import com.example.project_popq.support.repository.SupportInquiryRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminSupportInquiryService {

  private final SupportInquiryRepository supportInquiryRepository;
  private final SupportInquiryMessageRepository
      supportInquiryMessageRepository;

  public List<SupportInquirySummaryResponse> getInquiries(
      User admin,
      SupportInquiryStatus status
  ) {
    requireAdmin(admin);

    List<SupportInquiry> inquiries =
        status == null
            ? supportInquiryRepository
              .findAllByOrderByCreatedAtDescIdDesc()
            : supportInquiryRepository
              .findAllByStatusOrderByCreatedAtDescIdDesc(status);

    return inquiries.stream()
        .map(inquiry -> SupportInquirySummaryResponse.from(
            inquiry,
            countUnreadCustomerMessages(inquiry.getId())
        ))
        .toList();
  }

  @Transactional
  public SupportInquiryDetailResponse getInquiry(
      User admin,
      Long supportInquiryId
  ) {
    requireAdmin(admin);

    SupportInquiry inquiry = findInquiry(
        supportInquiryId
    );

    List<SupportInquiryMessage> messages =
        supportInquiryMessageRepository
            .findAllByInquiryIdOrderByCreatedAtAscIdAsc(
                inquiry.getId()
            );

    markCustomerMessagesAsRead(inquiry.getId());

    if (inquiry.getStatus() ==
        SupportInquiryStatus.RECEIVED) {
      inquiry.markInProgress();
    }

    return SupportInquiryDetailResponse.from(
        inquiry,
        messages,
        0L
    );
  }

  @Transactional
  public SupportInquiryDetailResponse sendAnswer(
      User admin,
      Long supportInquiryId,
      SendSupportMessageRequest request
  ) {
    requireAdmin(admin);

    SupportInquiry inquiry = findInquiry(
        supportInquiryId
    );

    if (inquiry.isClosed()) {
      throw new BusinessException(
          ErrorCode.SUPPORT_INQUIRY_CLOSED
      );
    }

    SupportInquiryMessage answer =
        SupportInquiryMessage.create(
            inquiry,
            admin,
            SupportMessageSenderType.ADMIN,
            normalizeRequired(request.content())
        );

    supportInquiryMessageRepository.save(answer);
    inquiry.markAnswered(Instant.now());

    markCustomerMessagesAsRead(inquiry.getId());

    List<SupportInquiryMessage> messages =
        supportInquiryMessageRepository
            .findAllByInquiryIdOrderByCreatedAtAscIdAsc(
                inquiry.getId()
            );

    return SupportInquiryDetailResponse.from(
        inquiry,
        messages,
        0L
    );
  }

  @Transactional
  public SupportInquirySummaryResponse changeStatus(
      User admin,
      Long supportInquiryId,
      ChangeSupportInquiryStatusRequest request
  ) {
    requireAdmin(admin);

    SupportInquiry inquiry = findInquiry(
        supportInquiryId
    );

    SupportInquiryStatus status = request.status();
    Instant now = Instant.now();

    switch (status) {
      case RECEIVED -> inquiry.reopen();
      case IN_PROGRESS -> inquiry.markInProgress();
      case ANSWERED -> inquiry.markAnswered(now);
      case CLOSED -> inquiry.close(now);
    }

    return SupportInquirySummaryResponse.from(
        inquiry,
        countUnreadCustomerMessages(inquiry.getId())
    );
  }

  public long getUnreadMessageCount(User admin) {
    requireAdmin(admin);

    return supportInquiryRepository
        .findAllByOrderByCreatedAtDescIdDesc()
        .stream()
        .mapToLong(inquiry ->
            countUnreadCustomerMessages(inquiry.getId())
        )
        .sum();
  }

  private SupportInquiry findInquiry(
      Long supportInquiryId
  ) {
    return supportInquiryRepository
        .findWithCustomerById(supportInquiryId)
        .orElseThrow(() -> new BusinessException(
            ErrorCode.SUPPORT_INQUIRY_NOT_FOUND
        ));
  }

  private long countUnreadCustomerMessages(
      Long supportInquiryId
  ) {
    return supportInquiryMessageRepository
        .countByInquiryIdAndSenderTypeAndReadAtIsNull(
            supportInquiryId,
            SupportMessageSenderType.CUSTOMER
        );
  }

  private void markCustomerMessagesAsRead(
      Long supportInquiryId
  ) {
    List<SupportInquiryMessage> unreadMessages =
        supportInquiryMessageRepository
            .findAllByInquiryIdAndSenderTypeAndReadAtIsNullOrderByCreatedAtAscIdAsc(
                supportInquiryId,
                SupportMessageSenderType.CUSTOMER
            );

    if (unreadMessages.isEmpty()) {
      return;
    }

    Instant now = Instant.now();

    unreadMessages.forEach(
        message -> message.markAsRead(now)
    );
  }

  private void requireAdmin(User user) {
    if (user == null ||
        !user.hasRole(PlatformRole.ADMIN)) {
      throw new BusinessException(
          ErrorCode.ACCESS_DENIED
      );
    }
  }

  private String normalizeRequired(String value) {
    if (value == null) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST
      );
    }

    String normalized = value.trim();

    if (normalized.isEmpty()) {
      throw new BusinessException(
          ErrorCode.INVALID_REQUEST
      );
    }

    return normalized;
  }
}