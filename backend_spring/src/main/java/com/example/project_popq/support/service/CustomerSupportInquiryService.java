package com.example.project_popq.support.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.support.domain.SupportInquiry;
import com.example.project_popq.support.domain.SupportInquiryMessage;
import com.example.project_popq.support.domain.SupportMessageSenderType;
import com.example.project_popq.support.dto.CreateSupportInquiryRequest;
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
public class CustomerSupportInquiryService {

  private final SupportInquiryRepository supportInquiryRepository;
  private final SupportInquiryMessageRepository
      supportInquiryMessageRepository;

  /**
   * 고객이 새로운 1:1 문의를 등록합니다.
   */
  @Transactional
  public SupportInquiryDetailResponse createInquiry(
      User customer,
      CreateSupportInquiryRequest request
  ) {
    requireCustomer(customer);

    SupportInquiry inquiry = SupportInquiry.create(
        customer,
        request.category(),
        normalizeRequired(request.title())
    );

    supportInquiryRepository.save(inquiry);

    SupportInquiryMessage message =
        SupportInquiryMessage.create(
            inquiry,
            customer,
            SupportMessageSenderType.CUSTOMER,
            normalizeRequired(request.content())
        );

    supportInquiryMessageRepository.save(message);

    return SupportInquiryDetailResponse.from(
        inquiry,
        List.of(message),
        0L
    );
  }

  /**
   * 로그인한 고객 본인의 문의 목록을 최신순으로 조회합니다.
   */
  public List<SupportInquirySummaryResponse> getMyInquiries(
      User customer
  ) {
    requireCustomer(customer);

    return supportInquiryRepository
        .findAllByCustomerIdOrderByCreatedAtDescIdDesc(
            customer.getId()
        )
        .stream()
        .map(inquiry -> SupportInquirySummaryResponse.from(
            inquiry,
            countUnreadAdminMessages(inquiry.getId())
        ))
        .toList();
  }

  /**
   * 로그인한 고객 본인의 문의 상세를 조회합니다.
   *
   * 상세 화면을 열면 관리자 메시지를 읽음 처리합니다.
   */
  @Transactional
  public SupportInquiryDetailResponse getMyInquiry(
      User customer,
      Long supportInquiryId
  ) {
    requireCustomer(customer);

    SupportInquiry inquiry = findOwnedInquiry(
        customer,
        supportInquiryId
    );

    List<SupportInquiryMessage> messages =
        supportInquiryMessageRepository
            .findAllByInquiryIdOrderByCreatedAtAscIdAsc(
                inquiry.getId()
            );

    markAdminMessagesAsRead(inquiry.getId());

    return SupportInquiryDetailResponse.from(
        inquiry,
        messages,
        0L
    );
  }

  /**
   * 기존 문의에 고객이 추가 메시지를 작성합니다.
   */
  @Transactional
  public SupportInquiryDetailResponse sendMessage(
      User customer,
      Long supportInquiryId,
      SendSupportMessageRequest request
  ) {
    requireCustomer(customer);

    SupportInquiry inquiry = findOwnedInquiry(
        customer,
        supportInquiryId
    );

    if (inquiry.isClosed()) {
      throw new BusinessException(
          ErrorCode.SUPPORT_INQUIRY_CLOSED
      );
    }

    SupportInquiryMessage message =
        SupportInquiryMessage.create(
            inquiry,
            customer,
            SupportMessageSenderType.CUSTOMER,
            normalizeRequired(request.content())
        );

    supportInquiryMessageRepository.save(message);

    inquiry.reopen();

    List<SupportInquiryMessage> messages =
        supportInquiryMessageRepository
            .findAllByInquiryIdOrderByCreatedAtAscIdAsc(
                inquiry.getId()
            );

    return SupportInquiryDetailResponse.from(
        inquiry,
        messages,
        countUnreadAdminMessages(inquiry.getId())
    );
  }

  private SupportInquiry findOwnedInquiry(
      User customer,
      Long supportInquiryId
  ) {
    return supportInquiryRepository
        .findByIdAndCustomerId(
            supportInquiryId,
            customer.getId()
        )
        .orElseThrow(() -> new BusinessException(
            ErrorCode.SUPPORT_INQUIRY_NOT_FOUND
        ));
  }

  private long countUnreadAdminMessages(
      Long supportInquiryId
  ) {
    return supportInquiryMessageRepository
        .countByInquiryIdAndSenderTypeAndReadAtIsNull(
            supportInquiryId,
            SupportMessageSenderType.ADMIN
        );
  }

  private void markAdminMessagesAsRead(
      Long supportInquiryId
  ) {
    List<SupportInquiryMessage> unreadMessages =
        supportInquiryMessageRepository
            .findAllByInquiryIdAndSenderTypeAndReadAtIsNullOrderByCreatedAtAscIdAsc(
                supportInquiryId,
                SupportMessageSenderType.ADMIN
            );

    if (unreadMessages.isEmpty()) {
      return;
    }

    Instant now = Instant.now();

    unreadMessages.forEach(
        message -> message.markAsRead(now)
    );
  }

  private void requireCustomer(User user) {
    if (user == null ||
        !user.hasRole(PlatformRole.CUSTOMER)) {
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