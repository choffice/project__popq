package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreTag;
import com.example.project_popq.store.dto.PublicStoreResponse;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.repository.StoreTagRepository;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PublicStoreQueryService {

    private static final double EARTH_RADIUS_METERS = 6_371_000.0;

    private final StoreRepository storeRepository;
    private final StoreTagRepository storeTagRepository;

    @Transactional(readOnly = true)
    public List<PublicStoreResponse> search(
            String query,
            String tag,
            BigDecimal latitude,
            BigDecimal longitude,
            Double radiusKm
    ) {
        validateLocation(latitude, longitude, radiusKm);
        List<Store> stores = storeRepository.searchPublicStores(
                normalize(query),
                normalize(tag)
        );
        Map<Long, List<String>> tagsByStore = findTags(stores);

        return stores.stream()
                .map(store -> toResponse(
                        store,
                        tagsByStore.getOrDefault(store.getId(), List.of()),
                        latitude,
                        longitude
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
        Store store = storeRepository.findByIdAndStatusAndBusinessStatus(
                        storeId,
                        StoreStatus.ACTIVE,
                        BusinessStatus.OPEN
                )
                .orElseThrow(() -> new BusinessException(ErrorCode.STORE_NOT_FOUND));
        List<String> tags = storeTagRepository.findAllByStoreId(storeId)
                .stream()
                .map(storeTag -> storeTag.getTag().getName())
                .sorted()
                .toList();
        return PublicStoreResponse.of(store, tags, null);
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
            BigDecimal longitude
    ) {
        Long distance = null;
        if (latitude != null && store.getLatitude() != null
                && store.getLongitude() != null) {
            distance = Math.round(distanceMeters(
                    latitude.doubleValue(),
                    longitude.doubleValue(),
                    store.getLatitude().doubleValue(),
                    store.getLongitude().doubleValue()
            ));
        }
        return PublicStoreResponse.of(store, tags, distance);
    }

    private void validateLocation(
            BigDecimal latitude,
            BigDecimal longitude,
            Double radiusKm
    ) {
        if ((latitude == null) != (longitude == null)) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
        if (radiusKm != null && (latitude == null || radiusKm <= 0 || radiusKm > 100)) {
            throw new BusinessException(ErrorCode.INVALID_REQUEST);
        }
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

    private double distanceMeters(
            double fromLatitude,
            double fromLongitude,
            double toLatitude,
            double toLongitude
    ) {
        double latitudeDistance = Math.toRadians(toLatitude - fromLatitude);
        double longitudeDistance = Math.toRadians(toLongitude - fromLongitude);
        double startLatitude = Math.toRadians(fromLatitude);
        double endLatitude = Math.toRadians(toLatitude);
        double haversine = Math.pow(Math.sin(latitudeDistance / 2), 2)
                + Math.cos(startLatitude) * Math.cos(endLatitude)
                * Math.pow(Math.sin(longitudeDistance / 2), 2);
        return EARTH_RADIUS_METERS * 2
                * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
    }
}
