package com.example.project_popq.store.service;

import com.example.project_popq.common.error.BusinessException;
import com.example.project_popq.common.error.ErrorCode;
import com.example.project_popq.product.domain.Tag;
import com.example.project_popq.product.domain.TagType;
import com.example.project_popq.product.repository.TagRepository;
import com.example.project_popq.store.domain.Store;
import com.example.project_popq.store.domain.StoreMember;
import com.example.project_popq.store.domain.StoreMemberStatus;
import com.example.project_popq.store.domain.StoreRole;
import com.example.project_popq.store.domain.StoreTable;
import com.example.project_popq.store.domain.StoreTag;
import com.example.project_popq.store.domain.StoreType;
import com.example.project_popq.store.dto.ChangeBusinessStatusRequest;
import com.example.project_popq.store.dto.CreateStoreRequest;
import com.example.project_popq.store.dto.CreateStoreTableRequest;
import com.example.project_popq.store.dto.SellerStoreDetailResponse;
import com.example.project_popq.store.dto.StoreSummaryResponse;
import com.example.project_popq.store.dto.StoreTableResponse;
import com.example.project_popq.store.dto.UpdateStoreRequest;
import com.example.project_popq.store.repository.StoreMemberRepository;
import com.example.project_popq.store.repository.StoreRepository;
import com.example.project_popq.store.repository.StoreTableRepository;
import com.example.project_popq.store.repository.StoreTagRepository;
import com.example.project_popq.user.domain.PlatformRole;
import com.example.project_popq.user.domain.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class StoreApplicationService {

    private final StoreRepository storeRepository;
    private final StoreMemberRepository storeMemberRepository;
    private final StoreTableRepository storeTableRepository;
    private final StoreTagRepository storeTagRepository;
    private final TagRepository tagRepository;
    private final StoreAuthorizationService storeAuthorizationService;

    @Transactional
    public StoreSummaryResponse create(
            User currentUser,
            CreateStoreRequest request
    ) {
        if (currentUser.getRole() != PlatformRole.SELLER
                && currentUser.getRole() != PlatformRole.ADMIN) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        validateLocation(
                request.latitude(),
                request.longitude()
        );

        validateOperatingHours(
                request.openTime(),
                request.closeTime()
        );

        Store store = Store.create(
                request.storeType(),
                request.name().trim(),
                normalizeOptionalText(request.description())
        );

        store.updateDiscoveryProfile(
                normalizeOptionalText(request.address()),
                request.latitude(),
                request.longitude()
        );

        store.updateBusinessProfile(
                normalizeOptionalText(
                        request.representativeCategory()
                ),
                normalizeOptionalText(
                        request.detailAddress()
                ),
                normalizeOptionalText(
                        request.imageUrl()
                ),
                normalizeOptionalText(
                        request.phone()
                )
        );

        store.updateOperatingPolicy(
                request.openTime(),
                request.closeTime(),
                normalizeClosedDays(
                        request.closedDays()
                ),
                defaultTrue(
                        request.takeoutAvailable()
                ),
                defaultTrue(
                        request.dineInAvailable()
                ),
                defaultTrue(
                        request.orderAcceptingEnabled()
                )
        );

        storeRepository.save(store);
        saveTags(store, request.tags());

        StoreMember owner = StoreMember.create(
                store,
                currentUser,
                StoreRole.OWNER
        );

        storeMemberRepository.save(owner);

        return StoreSummaryResponse.of(
                store,
                owner.getRole()
        );
    }

    @Transactional(readOnly = true)
    public List<StoreSummaryResponse> findMyStores(
            User currentUser
    ) {
        return storeMemberRepository
                .findAllByUserIdAndStatusOrderByIdAsc(
                        currentUser.getId(),
                        StoreMemberStatus.ACTIVE
                )
                .stream()
                .map(member -> StoreSummaryResponse.of(
                        member.getStore(),
                        member.getRole()
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public SellerStoreDetailResponse findOne(
            User currentUser,
            Long storeId
    ) {
        StoreMember member =
                storeAuthorizationService.requireAnyRole(
                        currentUser.getId(),
                        storeId,
                        StoreRole.OWNER,
                        StoreRole.MANAGER,
                        StoreRole.STAFF
                );

        return detail(member);
    }

    @Transactional
    public SellerStoreDetailResponse update(
            User currentUser,
            Long storeId,
            UpdateStoreRequest request
    ) {
        StoreMember member =
                storeAuthorizationService.requireAnyRole(
                        currentUser.getId(),
                        storeId,
                        StoreRole.OWNER,
                        StoreRole.MANAGER
                );

        validateLocation(
                request.latitude(),
                request.longitude()
        );

        Store store = member.getStore();

        LocalTime openTime =
                request.openTime() == null
                        ? store.getOpenTime()
                        : request.openTime();

        LocalTime closeTime =
                request.closeTime() == null
                        ? store.getCloseTime()
                        : request.closeTime();

        validateOperatingHours(
                openTime,
                closeTime
        );

        store.updateSellerProfile(
                request.name().trim(),
                normalizeOptionalText(
                        request.description()
                ),
                normalizeOptionalText(
                        request.address()
                ),
                request.latitude(),
                request.longitude()
        );

        store.updateBusinessProfile(
                resolveOptionalText(
                        store.getRepresentativeCategory(),
                        request.representativeCategory()
                ),
                resolveOptionalText(
                        store.getDetailAddress(),
                        request.detailAddress()
                ),
                resolveOptionalText(
                        store.getImageUrl(),
                        request.imageUrl()
                ),
                resolveOptionalText(
                        store.getPhone(),
                        request.phone()
                )
        );

        store.updateOperatingPolicy(
                openTime,
                closeTime,
                request.closedDays() == null
                        ? store.getClosedDays()
                        : normalizeClosedDays(
                        request.closedDays()
                ),
                request.takeoutAvailable() == null
                        ? store.isTakeoutAvailable()
                        : request.takeoutAvailable(),
                request.dineInAvailable() == null
                        ? store.isDineInAvailable()
                        : request.dineInAvailable(),
                request.orderAcceptingEnabled() == null
                        ? store.isOrderAcceptingEnabled()
                        : request.orderAcceptingEnabled()
        );

        storeTagRepository.deleteAllByStoreId(storeId);
        storeTagRepository.flush();

        saveTags(
                store,
                request.tags()
        );

        return detail(member);
    }

    @Transactional
    public StoreSummaryResponse changeBusinessStatus(
            User currentUser,
            Long storeId,
            ChangeBusinessStatusRequest request
    ) {
        StoreMember member =
                storeAuthorizationService.requireAnyRole(
                        currentUser.getId(),
                        storeId,
                        StoreRole.OWNER,
                        StoreRole.MANAGER
                );

        Store store = member.getStore();

        store.changeBusinessStatus(
                request.businessStatus()
        );

        return StoreSummaryResponse.of(
                store,
                member.getRole()
        );
    }

    @Transactional
    public StoreTableResponse createTable(
            User currentUser,
            Long storeId,
            CreateStoreTableRequest request
    ) {
        storeAuthorizationService.requireAnyRole(
                currentUser.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER
        );

        Store store = storeRepository.findById(storeId)
                .orElseThrow(() ->
                        new BusinessException(
                                ErrorCode.STORE_NOT_FOUND
                        )
                );

        if (store.getStoreType()
                != StoreType.LOCAL_STORE) {
            throw new BusinessException(
                    ErrorCode.STORE_TABLE_NOT_ALLOWED
            );
        }

        String tableCode = request.tableCode()
                .trim()
                .toUpperCase();

        if (storeTableRepository
                .existsByStoreIdAndTableCodeIgnoreCase(
                        storeId,
                        tableCode
                )) {
            throw new BusinessException(
                    ErrorCode.DUPLICATE_STORE_TABLE
            );
        }

        StoreTable table =
                storeTableRepository.save(
                        StoreTable.create(
                                store,
                                tableCode,
                                request.name().trim()
                        )
                );

        return StoreTableResponse.from(table);
    }

    @Transactional(readOnly = true)
    public List<StoreTableResponse> findTables(
            User currentUser,
            Long storeId
    ) {
        storeAuthorizationService.requireAnyRole(
                currentUser.getId(),
                storeId,
                StoreRole.OWNER,
                StoreRole.MANAGER,
                StoreRole.STAFF
        );

        return storeTableRepository
                .findAllByStoreIdOrderByIdAsc(storeId)
                .stream()
                .map(StoreTableResponse::from)
                .toList();
    }

    private String normalizeOptionalText(
            String value
    ) {
        if (value == null || value.isBlank()) {
            return null;
        }

        return value.trim();
    }

    private String resolveOptionalText(
            String currentValue,
            String requestedValue
    ) {
        if (requestedValue == null) {
            return currentValue;
        }

        return normalizeOptionalText(requestedValue);
    }

    private void validateLocation(
            BigDecimal latitude,
            BigDecimal longitude
    ) {
        if ((latitude == null)
                != (longitude == null)) {
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST
            );
        }
    }

    private void validateOperatingHours(
            LocalTime openTime,
            LocalTime closeTime
    ) {
        if ((openTime == null)
                != (closeTime == null)) {
            throw new BusinessException(
                    ErrorCode.INVALID_REQUEST
            );
        }
    }

    private boolean defaultTrue(
            Boolean value
    ) {
        return value == null || value;
    }

    private String normalizeClosedDays(
            List<DayOfWeek> closedDays
    ) {
        if (closedDays == null
                || closedDays.isEmpty()) {
            return null;
        }

        return closedDays.stream()
                .distinct()
                .map(DayOfWeek::name)
                .collect(Collectors.joining(","));
    }

    private void saveTags(
            Store store,
            List<String> requestedTags
    ) {
        if (requestedTags == null
                || requestedTags.isEmpty()) {
            return;
        }

        requestedTags.stream()
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .map(String::toLowerCase)
                .distinct()
                .map(name -> tagRepository
                        .findByNameIgnoreCaseAndTagType(
                                name,
                                TagType.STORE
                        )
                        .orElseGet(() ->
                                tagRepository.save(
                                        Tag.create(
                                                name,
                                                TagType.STORE
                                        )
                                )
                        )
                )
                .map(tag ->
                        StoreTag.create(
                                store,
                                tag
                        )
                )
                .forEach(
                        storeTagRepository::save
                );
    }

    private SellerStoreDetailResponse detail(
            StoreMember member
    ) {
        List<String> tags =
                storeTagRepository
                        .findAllByStoreId(
                                member.getStore().getId()
                        )
                        .stream()
                        .map(storeTag ->
                                storeTag.getTag().getName()
                        )
                        .toList();

        return SellerStoreDetailResponse.of(
                member.getStore(),
                member.getRole(),
                tags
        );
    }
}