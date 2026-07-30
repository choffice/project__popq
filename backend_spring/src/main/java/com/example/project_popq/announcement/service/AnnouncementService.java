package com.example.project_popq.announcement.service;

import com.example.project_popq.announcement.domain.Announcement;
import com.example.project_popq.announcement.dto.AnnouncementResponse;
import com.example.project_popq.announcement.dto.ChangeAnnouncementStatusRequest;
import com.example.project_popq.announcement.dto.SaveAnnouncementRequest;
import com.example.project_popq.announcement.repository.AnnouncementRepository;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.service.StoreAuthorizationService;
import com.example.project_popq.user.domain.User;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AnnouncementService {

    private final AnnouncementRepository announcementRepository;
    private final StoreRepository storeRepository;
    private final StoreAuthorizationService storeAuthorizationService;

    @Transactional(readOnly = true)
    public List<AnnouncementResponse> findAll(User user, Long storeId) {
        requireStoreMember(user, storeId);
        return announcementRepository
                .findAllByStoreIdOrderByCreatedAtDescIdDesc(storeId)
                .stream()
                .map(AnnouncementResponse::from)
                .toList();
    }

    @Transactional
    public AnnouncementResponse create(
            User user,
            Long storeId,
            SaveAnnouncementRequest request
    ) {
        requireManager(user, storeId);
        Store store = storeRepository.findById(storeId)
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        Announcement announcement = announcementRepository.save(
                Announcement.create(
                        store,
                        request.title().trim(),
                        request.content().trim()
                )
        );
        return AnnouncementResponse.from(announcement);
    }

    @Transactional
    public AnnouncementResponse update(
            User user,
            Long storeId,
            Long announcementId,
            SaveAnnouncementRequest request
    ) {
        requireManager(user, storeId);
        Announcement announcement = findOne(storeId, announcementId);
        announcement.update(
                request.title().trim(),
                request.content().trim()
        );
        return AnnouncementResponse.from(announcement);
    }

    @Transactional
    public AnnouncementResponse changeStatus(
            User user,
            Long storeId,
            Long announcementId,
            ChangeAnnouncementStatusRequest request
    ) {
        requireManager(user, storeId);
        Announcement announcement = findOne(storeId, announcementId);
        announcement.changeStatus(request.status(), Instant.now());
        return AnnouncementResponse.from(announcement);
    }

    private Announcement findOne(Long storeId, Long announcementId) {
        return announcementRepository
                .findByIdAndStoreId(announcementId, storeId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.ANNOUNCEMENT_NOT_FOUND
                ));
    }

    private void requireStoreMember(User user, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );
    }

    private void requireManager(User user, Long storeId) {
        storeAuthorizationService.requireAnyRole(
                user.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER
        );
    }
}

