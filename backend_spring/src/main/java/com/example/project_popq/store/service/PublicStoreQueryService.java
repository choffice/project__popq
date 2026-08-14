package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreTag;
import com.example.project_popq.store.dto.PublicStoreResponse;
import com.example.project_popq.store.dto.StoreScheduleResponse;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.repository.StoreTagRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PublicStoreQueryService {

    private static final ZoneId SEOUL_ZONE = ZoneId.of("Asia/Seoul");

    private static final List<BusinessStatus> DISCOVERABLE_BUSINESS_STATUSES =
            List.of(BusinessStatus.PRE_OPEN, BusinessStatus.OPEN);

    private final StoreRepository storeRepository;
    private final StoreTagRepository storeTagRepository;
    private final StoreScheduleService storeScheduleService;

    @Transactional(readOnly = true)
    public List<PublicStoreResponse> search(
            String query,
            String tag,
            BigDecimal latitude,
            BigDecimal longitude,
            Double radiusKm
    ) {
        StoreDiscoveryLocationPolicy.validateOptionalLocation(
                latitude, longitude, radiusKm
        );
        Instant now = Instant.now();
        LocalDate today = LocalDate.now(SEOUL_ZONE);
        List<Store> stores = storeRepository.searchPublicStores(
                normalize(query),
                normalize(tag),
                now,
                today
        );
        Map<Long, List<String>> tagsByStore = findTags(stores);
        Map<Long, StoreScheduleResponse> schedules =
                storeScheduleService.findAllForEvaluation(stores, now);
        return stores.stream()
                .map(store -> toResponse(
                        store,
                        tagsByStore.getOrDefault(store.getId(), List.of()),
                        latitude,
                        longitude,
                        schedules.get(store.getId())
                ))
                .filter(response -> radiusKm == null
                        || response.distanceMeters() != null
                        && response.distanceMeters() <= radiusKm * 1000)
                .sorted((left, right) -> compareDistance(
                        left.distanceMeters(),
                        right.distanceMeters()
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public PublicStoreResponse findDetail(Long storeId) {
        Store store = storeRepository.findPublicDetail(
                        storeId,
                        DISCOVERABLE_BUSINESS_STATUSES,
                        LocalDate.now(SEOUL_ZONE)
                )
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        StoreScheduleResponse schedule = storeScheduleService.find(store);
        List<String> tags = storeTagRepository.findAllByStoreId(storeId)
                .stream()
                .map(storeTag -> storeTag.getTag().getName())
                .sorted()
                .toList();
        return PublicStoreResponse.of(
                store, tags, null, schedule
        );
    }

    private Map<Long, List<String>> findTags(List<Store> stores) {
        if (stores.isEmpty()) {
            return Map.of();
        }
        List<Long> storeIds = stores.stream().map(Store::getId).toList();
        return storeTagRepository.findAllByStoreIdIn(storeIds)
                .stream()
                .collect(Collectors.groupingBy(
                        storeTag -> storeTag.getStore().getId(),
                        Collectors.mapping(
                                storeTag -> storeTag.getTag().getName(),
                                Collectors.collectingAndThen(
                                        Collectors.toList(),
                                        values -> values.stream().sorted().toList()
                                )
                        )
                ));
    }

    private PublicStoreResponse toResponse(
            Store store,
            List<String> tags,
            BigDecimal latitude,
            BigDecimal longitude,
            StoreScheduleResponse schedule
    ) {
        Long distance = null;
        if (latitude != null && store.getLatitude() != null
                && store.getLongitude() != null) {
            distance = Math.round(StoreDiscoveryLocationPolicy.distanceMeters(
                    latitude.doubleValue(),
                    longitude.doubleValue(),
                    store.getLatitude().doubleValue(),
                    store.getLongitude().doubleValue()
            ));
        }
        return PublicStoreResponse.of(
                store, tags, distance, schedule
        );
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private int compareDistance(Long left, Long right) {
        if (left == null && right == null) {
            return 0;
        }
        if (left == null) {
            return 1;
        }
        if (right == null) {
            return -1;
        }
        return left.compareTo(right);
    }

}
