package com.example.project_popq.engagement.dto;

import com.example.project_popq.engagement.domain.StoreInterest;
import com.example.project_popq.store.domain.BusinessStatus;
import com.example.project_popq.store.domain.StoreType;
import java.time.Instant;

public record StoreInterestResponse(
        Long storeId,
        StoreType storeType,
        String name,
        String description,
        String address,
        String detailAddress,
        String representativeCategory,
        String imageUrl,
        BusinessStatus businessStatus,
        Instant interestedAt
) {
    public static StoreInterestResponse from(StoreInterest interest) {
        return new StoreInterestResponse(
                interest.getStore().getId(),
                interest.getStore().getStoreType(),
                interest.getStore().getName(),
                interest.getStore().getDescription(),
                interest.getStore().getAddress(),
                interest.getStore().getDetailAddress(),
                interest.getStore().getRepresentativeCategory(),
                interest.getStore().getImageUrl(),
                interest.getStore().getBusinessStatus(),
                interest.getCreatedAt()
        );
    }
}
