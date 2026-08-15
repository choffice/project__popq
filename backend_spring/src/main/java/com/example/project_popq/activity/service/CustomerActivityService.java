package com.example.project_popq.activity.service;

import com.example.project_popq.activity.domain.CustomerActivitySource;
import com.example.project_popq.activity.domain.CustomerActivitySourceType;
import com.example.project_popq.activity.domain.CustomerActivityType;
import com.example.project_popq.activity.domain.CustomerBadgeTier;
import com.example.project_popq.activity.dto.CustomerAttendanceResponse;
import com.example.project_popq.activity.dto.CustomerActivitySummaryResponse;
import com.example.project_popq.activity.dto.RecordVisitResponse;
import com.example.project_popq.activity.repository.CustomerActivitySourceRepository;
import com.example.project_popq.qr.service.GuestQrService;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.user.domain.User;
import com.example.project_popq.user.repository.UserRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomerActivityService {

    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Seoul");

    private final CustomerActivitySourceRepository activityRepository;
    private final UserRepository userRepository;
    private final StoreRepository storeRepository;
    private final GuestQrService guestQrService;

    @Transactional(readOnly = true)
    public CustomerActivitySummaryResponse getSummary(User user) {
        return getSummary(user.getId());
    }

    @Transactional(readOnly = true)
    public CustomerActivitySummaryResponse getSummary(Long userId) {
        return CustomerActivitySummaryResponse.from(
                activityRepository.countQualifiedActivities(userId)
        );
    }

    @Transactional(readOnly = true)
    public CustomerBadgeTier getBadgeTier(Long userId) {
        return CustomerBadgeTier.from(
                activityRepository.countQualifiedActivities(userId)
        );
    }

    @Transactional(readOnly = true)
    public CustomerBadgeTier getPublicBadgeTier(User user) {
        if (!user.isEmblemVisible()) {
            return CustomerBadgeTier.NONE;
        }
        return CustomerBadgeTier.from(
                activityRepository.countQualifiedActivities(user.getId())
        );
    }

    @Transactional(readOnly = true)
    public CustomerAttendanceResponse getAttendance(User user) {
        LocalDate today = localDate(Instant.now());
        return attendanceResponse(user.getId(), today, false);
    }

    @Transactional
    public CustomerAttendanceResponse recordAttendance(User user) {
        Instant occurredAt = Instant.now();
        LocalDate today = localDate(occurredAt);
        String sourceKey = user.getId() + ":" + today;
        boolean newlyChecked = activityRepository.insertDailyAttendance(
                user.getId(),
                sourceKey,
                today,
                occurredAt
        ) == 1;
        return attendanceResponse(user.getId(), today, newlyChecked);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordOrderPurchase(
            Long userId,
            Long storeId,
            String orderPublicId,
            Instant occurredAt
    ) {
        record(
                userRepository.getReferenceById(userId),
                storeRepository.getReferenceById(storeId),
                CustomerActivityType.STORE_PURCHASE,
                CustomerActivitySourceType.ORDER,
                orderPublicId,
                occurredAt
        );
    }

    @Transactional
    public void revokeOrderPurchase(String orderPublicId, Instant revokedAt) {
        revokeOrderPurchaseSource(orderPublicId, revokedAt);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void revokeOrderPurchaseAfterCommit(
            String orderPublicId,
            Instant revokedAt
    ) {
        revokeOrderPurchaseSource(orderPublicId, revokedAt);
    }

    private void revokeOrderPurchaseSource(
            String orderPublicId,
            Instant revokedAt
    ) {
        activityRepository.findBySourceTypeAndSourceKey(
                        CustomerActivitySourceType.ORDER,
                        orderPublicId
                )
                .ifPresent(activity -> activity.revoke(revokedAt));
    }

    @Transactional
    public RecordVisitResponse recordQrVisit(User user, String rawQrToken) {
        Store store = guestQrService.resolveStoreForVisit(rawQrToken);
        if (store.getStoreType() != StoreType.EVENT_COMMERCE) {
            return new RecordVisitResponse(false, getSummary(user.getId()));
        }

        Instant occurredAt = Instant.now();
        LocalDate activityDate = localDate(occurredAt);
        String sourceKey = user.getId() + ":" + store.getId() + ":" + activityDate;
        boolean counted = record(
                user,
                store,
                CustomerActivityType.STORE_VISIT,
                CustomerActivitySourceType.QR_VISIT,
                sourceKey,
                occurredAt
        );
        if (counted) {
            activityRepository.flush();
        }
        return new RecordVisitResponse(counted, getSummary(user.getId()));
    }

    private boolean record(
            User user,
            Store store,
            CustomerActivityType activityType,
            CustomerActivitySourceType sourceType,
            String sourceKey,
            Instant occurredAt
    ) {
        LocalDate activityDate = localDate(occurredAt);
        CustomerActivitySource existing = activityRepository
                .findBySourceTypeAndSourceKey(sourceType, sourceKey)
                .orElse(null);
        if (existing != null) {
            return existing.reactivate(occurredAt, activityDate);
        }

        activityRepository.save(
                CustomerActivitySource.record(
                        user,
                        store,
                        activityType,
                        sourceType,
                        sourceKey,
                        activityDate,
                        occurredAt
                )
        );
        return true;
    }

    private LocalDate localDate(Instant occurredAt) {
        return occurredAt.atZone(BUSINESS_ZONE).toLocalDate();
    }

    private CustomerAttendanceResponse attendanceResponse(
            Long userId,
            LocalDate today,
            boolean newlyChecked
    ) {
        YearMonth month = YearMonth.from(today);
        List<LocalDate> checkedDates = activityRepository.findActiveDates(
                userId,
                CustomerActivityType.DAILY_ATTENDANCE,
                month.atDay(1),
                month.atEndOfMonth()
        );
        return new CustomerAttendanceResponse(
                today,
                checkedDates,
                checkedDates.contains(today),
                newlyChecked,
                getSummary(userId)
        );
    }
}
