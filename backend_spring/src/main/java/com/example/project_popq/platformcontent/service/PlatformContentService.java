package com.example.project_popq.platformcontent.service;

import com.example.project_popq.admin.domain.AdminAuditLog;
import com.example.project_popq.admin.repository.AdminAuditLogRepository;
import com.example.project_popq.common.api.PageResponse;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.platformcontent.domain.AppAudience;
import com.example.project_popq.platformcontent.domain.ContentStatus;
import com.example.project_popq.platformcontent.domain.Faq;
import com.example.project_popq.platformcontent.domain.PlatformAnnouncement;
import com.example.project_popq.platformcontent.dto.FaqRequest;
import com.example.project_popq.platformcontent.dto.FaqResponse;
import com.example.project_popq.platformcontent.dto.PlatformAnnouncementRequest;
import com.example.project_popq.platformcontent.dto.PlatformAnnouncementResponse;
import com.example.project_popq.platformcontent.repository.FaqRepository;
import com.example.project_popq.platformcontent.repository.PlatformAnnouncementRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PlatformContentService {

    private final PlatformAnnouncementRepository announcementRepository;
    private final FaqRepository faqRepository;
    private final AdminAuditLogRepository auditLogRepository;

    @Transactional(readOnly = true)
    public PageResponse<PlatformAnnouncementResponse> announcements(
            User admin,
            int page,
            int size,
            String query,
            AppAudience audience,
            ContentStatus status
    ) {
        requireAdmin(admin);
        String search = normalize(query);
        Specification<PlatformAnnouncement> specification = (root, ignored, builder) -> {
            var predicate = builder.conjunction();
            if (search != null) {
                String pattern = "%" + search.toLowerCase() + "%";
                predicate = builder.and(predicate, builder.or(
                        builder.like(builder.lower(root.get("title")), pattern),
                        builder.like(builder.lower(root.get("content")), pattern)
                ));
            }
            if (audience != null) {
                predicate = builder.and(predicate, builder.equal(root.get("audience"), audience));
            }
            if (status != null) {
                predicate = builder.and(predicate, builder.equal(root.get("status"), status));
            }
            return predicate;
        };
        return PageResponse.from(
                announcementRepository.findAll(specification, pageRequest(page, size))
                        .map(PlatformAnnouncementResponse::from)
        );
    }

    @Transactional
    public PlatformAnnouncementResponse createAnnouncement(
            User admin,
            PlatformAnnouncementRequest.Save request
    ) {
        requireAdmin(admin);
        validatePeriod(request.publishStartAt(), request.publishEndAt());
        PlatformAnnouncement announcement = announcementRepository.save(
                PlatformAnnouncement.create(
                        admin,
                        request.audience(),
                        request.title(),
                        request.content(),
                        request.publishStartAt(),
                        request.publishEndAt()
                )
        );
        auditLogRepository.save(AdminAuditLog.create(
                admin, "PLATFORM_ANNOUNCEMENT", announcement.getId(),
                "CREATE", null, announcement.getStatus(), "플랫폼 공지 작성"
        ));
        return PlatformAnnouncementResponse.from(announcement);
    }

    @Transactional
    public PlatformAnnouncementResponse updateAnnouncement(
            User admin,
            Long id,
            PlatformAnnouncementRequest.Save request
    ) {
        requireAdmin(admin);
        validatePeriod(request.publishStartAt(), request.publishEndAt());
        PlatformAnnouncement announcement = findAnnouncement(id);
        announcement.update(
                request.audience(), request.title(), request.content(),
                request.publishStartAt(), request.publishEndAt()
        );
        auditLogRepository.save(AdminAuditLog.create(
                admin, "PLATFORM_ANNOUNCEMENT", id,
                "UPDATE", null, announcement.getStatus(), "플랫폼 공지 수정"
        ));
        return PlatformAnnouncementResponse.from(announcement);
    }

    @Transactional
    public PlatformAnnouncementResponse changeAnnouncementStatus(
            User admin,
            Long id,
            PlatformAnnouncementRequest.ChangeStatus request
    ) {
        requireAdmin(admin);
        PlatformAnnouncement announcement = findAnnouncement(id);
        ContentStatus before = announcement.getStatus();
        announcement.changeStatus(request.status());
        auditLogRepository.save(AdminAuditLog.create(
                admin, "PLATFORM_ANNOUNCEMENT", id,
                "CHANGE_STATUS", before, request.status(), "플랫폼 공지 상태 변경"
        ));
        return PlatformAnnouncementResponse.from(announcement);
    }

    @Transactional(readOnly = true)
    public List<PlatformAnnouncementResponse> publishedAnnouncements(AppAudience audience) {
        requireSpecificAudience(audience);
        return announcementRepository.findPublished(audience, Instant.now()).stream()
                .map(PlatformAnnouncementResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public PlatformAnnouncementResponse publishedAnnouncement(
            AppAudience audience,
            Long id
    ) {
        requireSpecificAudience(audience);
        return announcementRepository.findPublishedById(id, audience, Instant.now())
                .map(PlatformAnnouncementResponse::from)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.PLATFORM_ANNOUNCEMENT_NOT_FOUND
                ));
    }

    @Transactional(readOnly = true)
    public PageResponse<FaqResponse> faqs(
            User admin,
            int page,
            int size,
            String query,
            AppAudience audience,
            ContentStatus status,
            String category
    ) {
        requireAdmin(admin);
        String search = normalize(query);
        String normalizedCategory = normalize(category);
        Specification<Faq> specification = (root, ignored, builder) -> {
            var predicate = builder.conjunction();
            if (search != null) {
                String pattern = "%" + search.toLowerCase() + "%";
                predicate = builder.and(predicate, builder.or(
                        builder.like(builder.lower(root.get("question")), pattern),
                        builder.like(builder.lower(root.get("answer")), pattern)
                ));
            }
            if (audience != null) {
                predicate = builder.and(predicate, builder.equal(root.get("audience"), audience));
            }
            if (status != null) {
                predicate = builder.and(predicate, builder.equal(root.get("status"), status));
            }
            if (normalizedCategory != null) {
                predicate = builder.and(
                        predicate,
                        builder.equal(builder.lower(root.get("category")), normalizedCategory.toLowerCase())
                );
            }
            return predicate;
        };
        return PageResponse.from(
                faqRepository.findAll(
                        specification,
                        PageRequest.of(
                                Math.max(0, page),
                                Math.max(1, Math.min(size, 100)),
                                Sort.by(Sort.Order.asc("displayOrder"), Sort.Order.asc("id"))
                        )
                ).map(FaqResponse::from)
        );
    }

    @Transactional
    public FaqResponse createFaq(User admin, FaqRequest.Save request) {
        requireAdmin(admin);
        Faq faq = faqRepository.save(Faq.create(
                admin, request.audience(), request.category(), request.question(),
                request.answer(), request.displayOrder()
        ));
        auditLogRepository.save(AdminAuditLog.create(
                admin, "FAQ", faq.getId(), "CREATE", null, faq.getStatus(), "FAQ 작성"
        ));
        return FaqResponse.from(faq);
    }

    @Transactional
    public FaqResponse updateFaq(User admin, Long id, FaqRequest.Save request) {
        requireAdmin(admin);
        Faq faq = findFaq(id);
        faq.update(
                request.audience(), request.category(), request.question(),
                request.answer(), request.displayOrder()
        );
        auditLogRepository.save(AdminAuditLog.create(
                admin, "FAQ", id, "UPDATE", null, faq.getStatus(), "FAQ 수정"
        ));
        return FaqResponse.from(faq);
    }

    @Transactional
    public FaqResponse changeFaqStatus(
            User admin,
            Long id,
            FaqRequest.ChangeStatus request
    ) {
        requireAdmin(admin);
        Faq faq = findFaq(id);
        ContentStatus before = faq.getStatus();
        faq.changeStatus(request.status());
        auditLogRepository.save(AdminAuditLog.create(
                admin, "FAQ", id, "CHANGE_STATUS", before, request.status(), "FAQ 상태 변경"
        ));
        return FaqResponse.from(faq);
    }

    @Transactional(readOnly = true)
    public List<FaqResponse> publishedFaqs(AppAudience audience) {
        if (audience == AppAudience.ALL) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST, "조회할 앱을 선택해 주세요.");
        }
        return faqRepository.findPublished(audience).stream()
                .map(FaqResponse::from)
                .toList();
    }

    private PlatformAnnouncement findAnnouncement(Long id) {
        return announcementRepository.findById(id).orElseThrow(
                () -> new BusinessException(ErrorCode.PLATFORM_ANNOUNCEMENT_NOT_FOUND)
        );
    }

    private Faq findFaq(Long id) {
        return faqRepository.findById(id).orElseThrow(
                () -> new BusinessException(ErrorCode.FAQ_NOT_FOUND)
        );
    }

    private void validatePeriod(Instant start, Instant end) {
        if (start != null && end != null && !end.isAfter(start)) {
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST,
                    "게시 종료 시각은 시작 시각보다 뒤여야 합니다."
            );
        }
    }

    private PageRequest pageRequest(int page, int size) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, 100)),
                Sort.by(Sort.Direction.DESC, "id")
        );
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private void requireAdmin(User user) {
        if (!user.hasRole(PlatformRole.ADMIN)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }
    }

    private void requireSpecificAudience(AppAudience audience) {
        if (audience == AppAudience.ALL) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST, "조회할 앱을 선택해 주세요.");
        }
    }
}
