package com.example.project_popq.announcement.service;

import com.example.project_popq.announcement.domain.AnnouncementStatus;
import com.example.project_popq.announcement.dto.AnnouncementResponse;
import com.example.project_popq.announcement.repository.AnnouncementRepository;
import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.repository.StoreRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PublicAnnouncementQueryService {

    private final AnnouncementRepository announcementRepository;
    private final StoreRepository storeRepository;

    @Transactional(readOnly = true)
    public List<AnnouncementResponse> findAll(Long storeId) {
        requireDiscoverableStore(storeId);
        return announcementRepository
                .findAllByStoreIdAndStatusOrderByPinnedDescPublishedAtDescIdDesc(
                        storeId,
                        AnnouncementStatus.PUBLISHED
                )
                .stream()
                .map(AnnouncementResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public AnnouncementResponse findOne(Long storeId, Long announcementId) {
        requireDiscoverableStore(storeId);
        return announcementRepository
                .findByIdAndStoreIdAndStatus(
                        announcementId,
                        storeId,
                        AnnouncementStatus.PUBLISHED
                )
                .map(AnnouncementResponse::from)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.ANNOUNCEMENT_NOT_FOUND
                ));
    }

    private void requireDiscoverableStore(Long storeId) {
        storeRepository.findByIdAndStatusAndBusinessStatusIn(
                storeId,
                StoreStatus.ACTIVE,
                List.of(BusinessStatus.PRE_OPEN, BusinessStatus.OPEN)
        ).orElseThrow(() -> new BusinessException(
                ErrorCode.STORE_NOT_FOUND
        ));
    }
}
