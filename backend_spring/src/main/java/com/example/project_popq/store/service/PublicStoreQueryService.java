package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.engagement.domain.ReviewStatus;
import com.example.project_popq.engagement.repository.ReviewRepository;
import com.example.project_popq.engagement.repository.StoreInterestRepository;
import com.example.project_popq.order.domain.OrderStatus;
import com.example.project_popq.order.repository.OrderRepository;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.dto.PublicStoreResponse;
import com.example.project_popq.store.dto.StoreScheduleResponse;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.repository.StoreTagRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.HashMap;
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
    private final OrderRepository orderRepository;
    private final ReviewRepository reviewRepository;
    private final StoreInterestRepository storeInterestRepository;

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
        Map<Long, PopularityStats> popularityByStore = findPopularityStats(stores);

        return stores.stream()
                .map(store -> toResponse(
                        store,
                        tagsByStore.getOrDefault(store.getId(), List.of()),
                        latitude,
                        longitude,
                        schedules.get(store.getId()),
                        popularityByStore.getOrDefault(
                                store.getId(),
                                PopularityStats.empty()
                        )
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
        PopularityStats popularity = findPopularityStats(List.of(store))
                .getOrDefault(storeId, PopularityStats.empty());

        return PublicStoreResponse.of(
                store,
                tags,
                null,
                schedule,
                popularity.completedOrderCount(),
                popularity.reviewCount(),
                popularity.averageRating(),
                popularity.favoriteCount()
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

    private Map<Long, PopularityStats> findPopularityStats(List<Store> stores) {
        if (stores.isEmpty()) {
            return Map.of();
        }

        List<Long> storeIds = stores.stream()
                .map(Store::getId)
                .toList();

        Map<Long, PopularityStats> result = new HashMap<>();
        storeIds.forEach(storeId -> result.put(storeId, PopularityStats.empty()));

        orderRepository.countByStoreIdsAndStatuses(
                        storeIds,
                        List.of(OrderStatus.COMPLETED)
                )
                .forEach(row -> {
                    Long storeId = ((Number) row[0]).longValue();
                    long completedOrderCount = ((Number) row[2]).longValue();
                    PopularityStats current = result.getOrDefault(
                            storeId,
                            PopularityStats.empty()
                    );
                    result.put(
                            storeId,
                            current.withCompletedOrderCount(completedOrderCount)
                    );
                });

        reviewRepository.summarizeByStoreIds(
                        storeIds,
                        ReviewStatus.ACTIVE
                )
                .forEach(row -> {
                    Long storeId = ((Number) row[0]).longValue();
                    long reviewCount = ((Number) row[1]).longValue();
                    double averageRating = row[2] instanceof Number number
                            ? number.doubleValue()
                            : 0.0;
                    PopularityStats current = result.getOrDefault(
                            storeId,
                            PopularityStats.empty()
                    );
                    result.put(
                            storeId,
                            current.withReviewSummary(
                                    reviewCount,
                                    averageRating
                            )
                    );
                });

        storeInterestRepository.countByStoreIds(storeIds)
                .forEach(row -> {
                    Long storeId = ((Number) row[0]).longValue();
                    long favoriteCount = ((Number) row[1]).longValue();
                    PopularityStats current = result.getOrDefault(
                            storeId,
                            PopularityStats.empty()
                    );
                    result.put(
                            storeId,
                            current.withFavoriteCount(favoriteCount)
                    );
                });

        return Map.copyOf(result);
    }

    private PublicStoreResponse toResponse(
            Store store,
            List<String> tags,
            BigDecimal latitude,
            BigDecimal longitude,
            StoreScheduleResponse schedule,
            PopularityStats popularity
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
                store,
                tags,
                distance,
                schedule,
                popularity.completedOrderCount(),
                popularity.reviewCount(),
                popularity.averageRating(),
                popularity.favoriteCount()
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

    private record PopularityStats(
            long completedOrderCount,
            long reviewCount,
            double averageRating,
            long favoriteCount
    ) {
        private static PopularityStats empty() {
            return new PopularityStats(0L, 0L, 0.0, 0L);
        }

        private PopularityStats withCompletedOrderCount(long value) {
            return new PopularityStats(
                    value,
                    reviewCount,
                    averageRating,
                    favoriteCount
            );
        }

        private PopularityStats withReviewSummary(long count, double average) {
            return new PopularityStats(
                    completedOrderCount,
                    count,
                    average,
                    favoriteCount
            );
        }

        private PopularityStats withFavoriteCount(long value) {
            return new PopularityStats(
                    completedOrderCount,
                    reviewCount,
                    averageRating,
                    value
            );
        }
    }
}