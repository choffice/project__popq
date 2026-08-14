package com.example.project_popq.store.service;

import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreStatus;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.dto.NearbyEventNameSuggestionResponse;
import com.example.project_popq.store.repository.StoreRepository;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SellerEventNameSuggestionService {

    private static final ZoneId SEOUL_ZONE = ZoneId.of("Asia/Seoul");

    private final StoreRepository storeRepository;

    @Transactional(readOnly = true)
    public List<NearbyEventNameSuggestionResponse> findNearby(
            BigDecimal latitude,
            BigDecimal longitude,
            Double radiusKm
    ) {
        StoreDiscoveryLocationPolicy.validateRequiredLocation(
                latitude, longitude, radiusKm
        );
        LocalDate today = LocalDate.now(SEOUL_ZONE);
        Map<String, Long> counts = storeRepository
                .findEventNameSuggestionCandidates(today)
                .stream()
                .filter(store -> isEligible(store, today))
                .filter(store -> StoreDiscoveryLocationPolicy.distanceMeters(
                        latitude.doubleValue(),
                        longitude.doubleValue(),
                        store.getLatitude().doubleValue(),
                        store.getLongitude().doubleValue()
                ) <= radiusKm * 1000)
                .collect(Collectors.groupingBy(
                        store -> store.getEventName().trim(),
                        TreeMap::new,
                        Collectors.counting()
                ));
        return counts.entrySet().stream()
                .map(entry -> new NearbyEventNameSuggestionResponse(
                        entry.getKey(), entry.getValue()
                ))
                .toList();
    }

    private boolean isEligible(Store store, LocalDate today) {
        return store.getStoreType() == StoreType.EVENT_COMMERCE
                && store.getEventName() != null
                && !store.getEventName().isBlank()
                && store.getOperationEndDate() != null
                && !store.getOperationEndDate().isBefore(today)
                && store.getStatus() == StoreStatus.ACTIVE
                && (store.getBusinessStatus() == BusinessStatus.PRE_OPEN
                    || store.getBusinessStatus() == BusinessStatus.OPEN)
                && store.getLatitude() != null
                && store.getLongitude() != null;
    }
}
